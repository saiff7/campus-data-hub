/*
tSQLt tests for the Power BI star schema (bi): the data-as-of row, date coverage, surrogate-key
integrity against the masked student dimension, and schema-level access for IR only. The
direct-identifier column check for bi is in SecurityTests.
*/
EXEC tSQLt.NewTestClass @ClassName = N'BiTests';
GO

CREATE PROCEDURE [BiTests].[test data-as-of always returns exactly one row]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'audit.BatchRun';
    DECLARE @EmptyPlatform INT = (SELECT COUNT(*) FROM [bi].[DataAsOf]);

    INSERT INTO [audit].[BatchRun] ([BatchId], [ProcessName], [BatchStatusCode], [EndedAtUtc])
    VALUES (7, 'NIGHTLY_INTEGRATION', 'SUCCEEDED', '2026-10-05T02:05:00'), (9, 'NIGHTLY_INTEGRATION', 'FAILED', '2026-10-06T02:05:00');
    INSERT INTO [audit].[BatchRun] ([BatchId], [ProcessName], [SourceSystemCode], [ParentBatchId], [SourceWatermarkUtc])
    VALUES (8, 'LANDING_J1_SIM', 'J1_SIM', 7, '2026-10-05T01:00:00');

    SELECT d.[LastSuccessfulRunId], d.[J1WatermarkUtc] INTO #Actual FROM [bi].[DataAsOf] AS d;
    SELECT TOP (0) a.[LastSuccessfulRunId], a.[J1WatermarkUtc] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([LastSuccessfulRunId], [J1WatermarkUtc]) VALUES (7, '2026-10-05T01:00:00');

    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @EmptyPlatform;
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [BiTests].[test the date dimension covers four academic years with unique keys]
AS
BEGIN
    DECLARE @Days INT = (SELECT COUNT(*) FROM [bi].[DimDate]);
    DECLARE @Keys INT = (SELECT COUNT(DISTINCT d.[DateKey]) FROM [bi].[DimDate] AS d);
    DECLARE @First DATE = (SELECT MIN(d.[Date]) FROM [bi].[DimDate] AS d);
    DECLARE @Last DATE = (SELECT MAX(d.[Date]) FROM [bi].[DimDate] AS d);

    EXEC tSQLt.AssertEquals @Expected = 1461, @Actual = @Days;
    EXEC tSQLt.AssertEquals @Expected = @Days, @Actual = @Keys;
    DECLARE @ExpectedFirst DATE = '2024-07-01';
    DECLARE @ExpectedLast DATE = '2028-06-30';

    EXEC tSQLt.AssertEquals @Expected = @ExpectedFirst, @Actual = @First;
    EXEC tSQLt.AssertEquals @Expected = @ExpectedLast, @Actual = @Last;
END;
GO

CREATE PROCEDURE [BiTests].[test every student fact row has a masked student]
AS
BEGIN
    -- Runs against the deployed data: a staged student without a surrogate key would break the
    -- star schema's relationships in Power BI.
    SELECT 'FactCensusEnrollment' AS [FactName], COUNT(*) AS [Orphans]
    INTO #Orphans
    FROM [bi].[FactCensusEnrollment] AS f
    WHERE f.[StudentKey] IS NULL AND f.[ExclusionReason] IS NULL
    UNION ALL
    SELECT 'FactAidAward' AS [FactName], COUNT(*) AS [Orphans]
    FROM [bi].[FactAidAward] AS f
    WHERE NOT EXISTS (SELECT 1 FROM [bi].[DimStudent] AS d WHERE d.[StudentKey] = f.[StudentKey])
    UNION ALL
    SELECT 'FactAccountBalance' AS [FactName], COUNT(*) AS [Orphans]
    FROM [bi].[FactAccountBalance] AS f
    WHERE NOT EXISTS (SELECT 1 FROM [bi].[DimStudent] AS d WHERE d.[StudentKey] = f.[StudentKey]);

    DELETE FROM #Orphans WHERE [Orphans] = 0;
    EXEC tSQLt.AssertEmptyTable @TableName = N'#Orphans';
END;
GO

CREATE PROCEDURE [BiTests].[test only IR analysts can read the star schema]
AS
BEGIN
    EXEC [SecurityTests].[AddRoleUser] @RoleName = N'role_ir_analyst';
    EXEC [SecurityTests].[AddRoleUser] @RoleName = N'role_enrollment_reporter';
    DECLARE @Analyst INT;
    DECLARE @Reporter INT;

    EXEC [SecurityTests].[TrySelect] @UserName = N'test_role_ir_analyst', @ObjectName = N'[bi].[DimStudent]', @Allowed = @Analyst OUTPUT;
    EXEC [SecurityTests].[TrySelect]
        @UserName = N'test_role_enrollment_reporter', @ObjectName = N'[bi].[DimStudent]', @Allowed = @Reporter OUTPUT;

    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Analyst;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Reporter;
END;
GO
