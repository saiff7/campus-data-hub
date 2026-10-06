/*
tSQLt tests for the landing loaders (ADR-002). Source views are faked, so the tests control
exactly what the "source" returns without touching the SourceSystems database.
SetFakeViewOn lets the test procedures that insert into multi-table views compile; it is
switched off again at the end of this file.
*/
EXEC tSQLt.NewTestClass @ClassName = N'LandingTests';
GO

-- Clear any state left by an interrupted earlier run before switching it on.
EXEC tSQLt.SetFakeViewOff @SchemaName = N'landing';
GO

EXEC tSQLt.SetFakeViewOn @SchemaName = N'landing';
GO

-- Fakes are created in SetUp, before the test procedure compiles, so its INSERTs resolve to
-- the fake tables rather than to the multi-table source views.
CREATE PROCEDURE [LandingTests].[SetUp]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'landing.vw_SourceSlateApplicant';
    EXEC tSQLt.FakeTable @TableName = N'landing.vw_SourceSlateApplication';
    EXEC tSQLt.FakeTable @TableName = N'landing.SlateApplicantRaw', @Identity = 1;
    EXEC tSQLt.FakeTable @TableName = N'landing.SlateApplicationRaw', @Identity = 1;
END;
GO

CREATE PROCEDURE [LandingTests].[test an unchanged row is counted as unchanged and not landed again]
AS
BEGIN
    INSERT INTO [landing].[vw_SourceSlateApplicant] ([PersonId], [FirstName], [LastName], [BirthDate], [SourceUpdatedAtUtc])
    VALUES ('A0000000-0000-4000-8000-000000000001', N'Ada', N'Byron', '2005-01-01', '2026-05-01T00:00:00');

    DECLARE @Read INT;
    DECLARE @Inserted INT;
    DECLARE @Watermark DATETIME2 (3);

    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 1, @PreviousWatermarkUtc = NULL,
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;
    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 2, @PreviousWatermarkUtc = @Watermark,
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;

    DECLARE @Landed INT = (SELECT COUNT(*) FROM [landing].[SlateApplicantRaw]);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Read, @Message = N'second load reads the boundary row';
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Inserted, @Message = N'second load inserts nothing';
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Landed, @Message = N'one landed version';
END;
GO

CREATE PROCEDURE [LandingTests].[test a changed row lands a new version]
AS
BEGIN
    INSERT INTO [landing].[vw_SourceSlateApplicant] ([PersonId], [FirstName], [LastName], [Email], [SourceUpdatedAtUtc])
    VALUES ('A0000000-0000-4000-8000-000000000001', N'Ada', N'Byron', N'ada@example.com', '2026-05-01T00:00:00');

    DECLARE @Read INT;
    DECLARE @Inserted INT;
    DECLARE @Watermark DATETIME2 (3);

    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 1, @PreviousWatermarkUtc = NULL,
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;

    UPDATE v
    SET v.[Email] = N'ada.byron@example.com', v.[SourceUpdatedAtUtc] = '2026-05-02T00:00:00'
    FROM [landing].[vw_SourceSlateApplicant] AS v;

    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 2, @PreviousWatermarkUtc = @Watermark,
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;

    SELECT r.[BatchId], r.[Email]
    INTO #Actual
    FROM [landing].[SlateApplicantRaw] AS r;

    SELECT TOP (0) a.[BatchId], a.[Email] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([BatchId], [Email])
    VALUES (1, N'ada@example.com'), (2, N'ada.byron@example.com');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
    DECLARE @ExpectedWatermark DATETIME2 (3) = '2026-05-02T00:00:00';
    EXEC tSQLt.AssertEquals @Expected = @ExpectedWatermark, @Actual = @Watermark;
END;
GO

-- Regression test for the defect found in Part 2: comparing with any earlier version instead
-- of the latest would skip the return to A and leave staging on B.
CREATE PROCEDURE [LandingTests].[test a value that changes back to an earlier version lands again]
AS
BEGIN
    INSERT INTO [landing].[vw_SourceSlateApplicant] ([PersonId], [LastName], [SourceUpdatedAtUtc])
    VALUES ('A0000000-0000-4000-8000-000000000001', N'A', '2026-05-01T00:00:00');

    DECLARE @Read INT;
    DECLARE @Inserted INT;
    DECLARE @Watermark DATETIME2 (3);

    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 1, @PreviousWatermarkUtc = NULL,
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;
    UPDATE v SET v.[LastName] = N'B', v.[SourceUpdatedAtUtc] = '2026-05-02T00:00:00' FROM [landing].[vw_SourceSlateApplicant] AS v;
    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 2, @PreviousWatermarkUtc = @Watermark,
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;
    UPDATE v SET v.[LastName] = N'A', v.[SourceUpdatedAtUtc] = '2026-05-03T00:00:00' FROM [landing].[vw_SourceSlateApplicant] AS v;
    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 3, @PreviousWatermarkUtc = @Watermark,
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;

    DECLARE @LatestLastName NVARCHAR (100) = (
        SELECT TOP (1) r.[LastName] FROM [landing].[SlateApplicantRaw] AS r ORDER BY r.[BatchId] DESC
    );
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Inserted, @Message = N'third load lands the return to A';
    EXEC tSQLt.AssertEquals @Expected = N'A', @Actual = @LatestLastName;
END;
GO

CREATE PROCEDURE [LandingTests].[test rows changed before the watermark are not read]
AS
BEGIN
    INSERT INTO [landing].[vw_SourceSlateApplicant] ([PersonId], [LastName], [SourceUpdatedAtUtc])
    VALUES
        ('A0000000-0000-4000-8000-000000000001', N'Old', '2026-04-30T23:59:59.999'),
        ('A0000000-0000-4000-8000-000000000002', N'Boundary', '2026-05-01T00:00:00'),
        ('A0000000-0000-4000-8000-000000000003', N'New', '2026-05-02T00:00:00');

    DECLARE @Read INT;
    DECLARE @Inserted INT;
    DECLARE @Watermark DATETIME2 (3);

    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 1, @PreviousWatermarkUtc = '2026-05-01T00:00:00',
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;

    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @Read;
    DECLARE @ExpectedWatermark DATETIME2 (3) = '2026-05-02T00:00:00';
    EXEC tSQLt.AssertEquals @Expected = @ExpectedWatermark, @Actual = @Watermark;
END;
GO

CREATE PROCEDURE [LandingTests].[test an empty source keeps the previous watermark]
AS
BEGIN

    DECLARE @Read INT;
    DECLARE @Inserted INT;
    DECLARE @Watermark DATETIME2 (3);

    EXEC [landing].[usp_LoadSlateSim]
        @BatchId = 1, @PreviousWatermarkUtc = '2026-05-01T00:00:00',
        @RowsRead = @Read OUTPUT, @RowsInserted = @Inserted OUTPUT, @SourceWatermarkUtc = @Watermark OUTPUT;

    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Read;
    DECLARE @ExpectedWatermark DATETIME2 (3) = '2026-05-01T00:00:00';
    EXEC tSQLt.AssertEquals @Expected = @ExpectedWatermark, @Actual = @Watermark;
END;
GO

-- The loader under test rolls back its own transaction, so this test runs outside tSQLt's
-- transaction; every table it touches is faked and tSQLt restores them afterwards.
--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [LandingTests].[test a failed load lands nothing, logs the error and closes the batch FAILED]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'audit.BatchRun', @Identity = 1;
    EXEC tSQLt.FakeTable @TableName = N'audit.ErrorLog', @Identity = 1;
    EXEC tSQLt.SpyProcedure
        @ProcedureName = N'landing.usp_LoadSlateSim',
        @CommandToExecute = N'INSERT INTO landing.SlateApplicantRaw (BatchId) VALUES (@BatchId);
            THROW 50999, N''Simulated source read failure.'', 1;';

    DECLARE @LandingBatchId BIGINT;
    DECLARE @Failed BIT = 0;

    BEGIN TRY
        EXEC [landing].[usp_RunLandingLoad] @SourceSystemCode = 'SLATE_SIM', @LandingBatchId = @LandingBatchId OUTPUT;
    END TRY
    BEGIN CATCH
        SET @Failed = 1;
    END CATCH;

    -- OUTPUT parameters are not assigned when the procedure throws, so read the batch back.
    SET @LandingBatchId = (SELECT br.[BatchId] FROM [audit].[BatchRun] AS br);
    DECLARE @Status VARCHAR (20) = (SELECT br.[BatchStatusCode] FROM [audit].[BatchRun] AS br);
    DECLARE @Watermark DATETIME2 (3) = (SELECT br.[SourceWatermarkUtc] FROM [audit].[BatchRun] AS br);
    DECLARE @Errors INT = (
        SELECT COUNT(*) FROM [audit].[ErrorLog] AS e WHERE e.[BatchId] = @LandingBatchId AND e.[ErrorNumber] = 50999
    );
    DECLARE @Landed INT = (SELECT COUNT(*) FROM [landing].[SlateApplicantRaw]);

    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Failed, @Message = N'error is re-thrown to the caller';
    EXEC tSQLt.AssertEquals @Expected = 'FAILED', @Actual = @Status;
    EXEC tSQLt.AssertEquals @Expected = NULL, @Actual = @Watermark, @Message = N'watermark does not advance';
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Errors;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Landed, @Message = N'partial rows are rolled back';
END;
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'landing';
GO
