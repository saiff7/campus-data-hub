/*
tSQLt tests for census snapshots (ADR-003): capture rules, refusals, idempotency, immutability
and tamper detection. core.vw_StudentTermCensus is faked so each test controls the population.
SetFakeViewOn lets the procedures that insert into that multi-table view compile; it is switched
off again at the end of this file.
*/
EXEC tSQLt.NewTestClass @ClassName = N'CensusTests';
GO

-- Clear any state left by an interrupted earlier run before switching it on.
EXEC tSQLt.SetFakeViewOff @SchemaName = N'core';
GO

EXEC tSQLt.SetFakeViewOn @SchemaName = N'core';
GO

CREATE PROCEDURE [CensusTests].[AddPopulation]
AS
BEGIN
    INSERT INTO [core].[vw_StudentTermCensus] (
        [IdNumber], [TermCode], [HasStudentRecord], [ProgramCode], [CensusCredits], [CountedSections],
        [SectionsRegisteredByCensus], [EntryStatus], [AgeAtCensus]
    )
    VALUES
        (2400001, '2025FA', 1, 'CIS.AS', 12.0, 4, 4, 'ENTERING', 19),
        (2400002, '2025FA', 1, 'CIS.AS', 11.5, 4, 4, 'CONTINUING', 22),
        (2400003, '2025FA', 1, 'NURS.AS', 0.0, 0, 2, 'CONTINUING', 30),
        (2400004, '2025FA', 1, 'NURS.AS', 0.0, 0, 0, 'ENTERING', 18),
        (2499999, '2025FA', 0, NULL, 3.0, 1, 1, NULL, NULL);
END;
GO

CREATE PROCEDURE [CensusTests].[SetUp]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_StudentTermCensus';
    EXEC tSQLt.FakeTable @TableName = N'audit.BatchRun';
    EXEC tSQLt.FakeTable @TableName = N'reference.AcademicTerm';
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusRuleVersion';
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusSnapshot', @Identity = 1, @ComputedColumns = 1;
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusSnapshotEnrollment';

    INSERT INTO [reference].[AcademicTerm] ([TermCode], [TermType], [CensusDate]) VALUES ('2025FA', 'FALL', '2025-09-16');
    INSERT INTO [compliance].[CensusRuleVersion] ([RuleVersion], [FullTimeMinCredits], [IsCurrent]) VALUES ('CENSUS-T', 12.0, 1);
    INSERT INTO [audit].[BatchRun] ([BatchId], [ProcessName], [BatchStatusCode]) VALUES (7, 'NIGHTLY_INTEGRATION', 'SUCCEEDED');
    INSERT INTO [audit].[BatchRun] ([BatchId], [ProcessName], [SourceSystemCode], [ParentBatchId], [BatchStatusCode], [SourceWatermarkUtc])
    VALUES (8, 'LANDING_J1_SIM', 'J1_SIM', 7, 'SUCCEEDED', '2025-09-30T10:00:00');

    -- A separate procedure compiles after the fake exists, so its INSERT resolves to the fake.
    EXEC [CensusTests].[AddPopulation];
END;
GO

CREATE PROCEDURE [CensusTests].[test capture applies the rule version and records exclusions]
AS
BEGIN
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-16';

    SELECT e.[IdNumber], e.[AttendanceIntensity], e.[IsCensusIncluded], e.[ExclusionReason]
    INTO #Actual
    FROM [compliance].[CensusSnapshotEnrollment] AS e;

    SELECT TOP (0) a.[IdNumber], a.[AttendanceIntensity], a.[IsCensusIncluded], a.[ExclusionReason]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected ([IdNumber], [AttendanceIntensity], [IsCensusIncluded], [ExclusionReason])
    VALUES
        (2400001, 'FULL_TIME', 1, NULL),
        (2400002, 'PART_TIME', 1, NULL),
        (2400003, NULL, 0, 'DROPPED_BEFORE_CENSUS'),
        (2400004, NULL, 0, 'REGISTERED_AFTER_CENSUS'),
        (2499999, NULL, 0, 'NO_STUDENT_RECORD');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [CensusTests].[test the header records counts, lineage and a verifiable checksum]
AS
BEGIN
    DECLARE @SnapshotId INT;
    DECLARE @IsValid BIT;
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-16', @CensusSnapshotId = @SnapshotId OUTPUT;

    SELECT
        s.[RuleVersion], s.[SourceBatchId], s.[SourceWatermarkUtc], s.[PopulationCount], s.[IncludedCount], s.[FullTimeCount],
        s.[CreditTotal]
    INTO #Actual
    FROM [compliance].[CensusSnapshot] AS s;

    SELECT TOP (0)
        a.[RuleVersion], a.[SourceBatchId], a.[SourceWatermarkUtc], a.[PopulationCount], a.[IncludedCount], a.[FullTimeCount],
        a.[CreditTotal]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected (
        [RuleVersion], [SourceBatchId], [SourceWatermarkUtc], [PopulationCount], [IncludedCount], [FullTimeCount], [CreditTotal]
    )
    VALUES ('CENSUS-T', 7, '2025-09-30T10:00:00', 5, 2, 1, 23.5);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    CREATE TABLE #Verify ([CensusSnapshotId] INT, [StoredChecksum] CHAR (64), [RecomputedChecksum] CHAR (64), [IsValid] BIT);
    INSERT INTO #Verify EXEC [compliance].[usp_VerifyCensusSnapshot] @CensusSnapshotId = @SnapshotId;
    SET @IsValid = (SELECT v.[IsValid] FROM #Verify AS v);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @IsValid;
END;
GO

CREATE PROCEDURE [CensusTests].[test capturing again returns the existing snapshot and writes nothing]
AS
BEGIN
    DECLARE @First INT;
    DECLARE @Second INT;
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-16', @CensusSnapshotId = @First OUTPUT;

    -- The live population changes after census; the existing snapshot must be returned unchanged.
    DELETE FROM [core].[vw_StudentTermCensus] WHERE [IdNumber] = 2400001;
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-10-01', @CensusSnapshotId = @Second OUTPUT;

    DECLARE @Rows INT = (SELECT COUNT(*) FROM [compliance].[CensusSnapshotEnrollment]);
    DECLARE @Headers INT = (SELECT COUNT(*) FROM [compliance].[CensusSnapshot]);
    EXEC tSQLt.AssertEquals @Expected = @First, @Actual = @Second;
    EXEC tSQLt.AssertEquals @Expected = 5, @Actual = @Rows;
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Headers;
END;
GO

CREATE PROCEDURE [CensusTests].[test a changed rule version captures a second snapshot beside the first]
AS
BEGIN
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-16';

    UPDATE r SET r.[IsCurrent] = 0 FROM [compliance].[CensusRuleVersion] AS r;
    INSERT INTO [compliance].[CensusRuleVersion] ([RuleVersion], [FullTimeMinCredits], [IsCurrent]) VALUES ('CENSUS-T2', 11.5, 1);
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-16';

    SELECT s.[RuleVersion], s.[FullTimeCount] INTO #Actual FROM [compliance].[CensusSnapshot] AS s;
    SELECT TOP (0) a.[RuleVersion], a.[FullTimeCount] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([RuleVersion], [FullTimeCount]) VALUES ('CENSUS-T', 1), ('CENSUS-T2', 2);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [CensusTests].[test verification detects changed snapshot rows]
AS
BEGIN
    DECLARE @SnapshotId INT;
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-16', @CensusSnapshotId = @SnapshotId OUTPUT;

    -- The faked table has no immutability trigger, which simulates tampering by a privileged user.
    UPDATE e SET e.[CensusCredits] = 15.0 FROM [compliance].[CensusSnapshotEnrollment] AS e WHERE e.[IdNumber] = 2400002;

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52011;
    EXEC [compliance].[usp_VerifyCensusSnapshot] @CensusSnapshotId = @SnapshotId;
END;
GO

CREATE PROCEDURE [CensusTests].[test snapshot rows cannot be updated]
AS
BEGIN
    EXEC tSQLt.ApplyTrigger @TableName = N'compliance.CensusSnapshotEnrollment', @TriggerName = N'trg_CensusSnapshotEnrollment_Immutable';
    INSERT INTO [compliance].[CensusSnapshotEnrollment] (
        [CensusSnapshotId], [IdNumber], [CensusCredits], [CountedSections], [IsCensusIncluded]
    )
    VALUES (1, 2400001, 12.0, 4, 1);

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52010;
    UPDATE e SET e.[CensusCredits] = 3.0 FROM [compliance].[CensusSnapshotEnrollment] AS e;
END;
GO

CREATE PROCEDURE [CensusTests].[test snapshot headers cannot be deleted]
AS
BEGIN
    EXEC tSQLt.ApplyTrigger @TableName = N'compliance.CensusSnapshot', @TriggerName = N'trg_CensusSnapshot_Immutable';
    INSERT INTO [compliance].[CensusSnapshot] ([TermCode], [RuleVersion]) VALUES ('2025FA', 'CENSUS-T');

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52010;
    DELETE FROM [compliance].[CensusSnapshot];
END;
GO

CREATE PROCEDURE [CensusTests].[test a row that is not included must carry an exclusion reason]
AS
BEGIN
    EXEC tSQLt.ApplyConstraint
        @TableName = N'compliance.CensusSnapshotEnrollment', @ConstraintName = N'CK_compliance_CensusSnapshotEnrollment_Inclusion';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 547;
    INSERT INTO [compliance].[CensusSnapshotEnrollment] (
        [CensusSnapshotId], [IdNumber], [CensusCredits], [CountedSections], [IsCensusIncluded]
    )
    VALUES (1, 2400001, 0.0, 0, 0);
END;
GO

-- Refusals throw before any transaction, but XACT_ABORT ends tSQLt's own transaction, so these
-- run outside it.
--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [CensusTests].[test capture is refused before the census date]
AS
BEGIN
    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52003;
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-15';
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [CensusTests].[test capture is refused while a nightly run is running]
AS
BEGIN
    INSERT INTO [audit].[BatchRun] ([BatchId], [ProcessName], [BatchStatusCode]) VALUES (9, 'NIGHTLY_INTEGRATION', 'RUNNING');

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52005;
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-16';
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [CensusTests].[test capture is refused before any nightly run has succeeded]
AS
BEGIN
    DELETE FROM [audit].[BatchRun];

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52006;
    EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = '2025FA', @AsOfDate = '2025-09-16';
END;
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'core';
GO
