/*
Post-deployment smoke test. Run against CampusDataOps after deploy and seed:
    make smoke
Checks structure, reference and data-quality metadata, simulator data, edge cases,
cross-database agreement and the landing batch-control round trip. Every check runs; failures are reported together and
the script then raises an error so sqlcmd -b exits non-zero. It leaves no rows behind.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Failure TABLE (
    [CheckName] NVARCHAR (200)  NOT NULL,
    [Detail]    NVARCHAR (1000) NOT NULL
);
DECLARE @Actual INT;

-- Structure ---------------------------------------------------------------------------
SELECT @Actual = COUNT(*)
FROM sys.schemas AS s
WHERE s.[name] IN (
    N'landing', N'staging', N'core', N'integration', N'dq',
    N'reporting', N'compliance', N'security', N'audit', N'reference'
);
IF @Actual <> 10
    INSERT INTO @Failure VALUES (N'CampusDataOps schemas', CONCAT(N'expected 10, found ', @Actual));

SELECT @Actual = COUNT(*)
FROM [SourceSystems].sys.schemas AS s
WHERE s.[name] IN (N'SlateSim', N'J1Sim', N'DirectorySim');
IF @Actual <> 3
    INSERT INTO @Failure VALUES (N'SourceSystems schemas', CONCAT(N'expected 3, found ', @Actual));

-- Reference data ----------------------------------------------------------------------
SELECT @Actual = COUNT(*) FROM [reference].[SourceSystem] WHERE [IsActive] = 1;
IF @Actual <> 3 INSERT INTO @Failure VALUES (N'Active source systems', CONCAT(N'expected 3, found ', @Actual));

SELECT @Actual = COUNT(*) FROM [reference].[BatchStatus];
IF @Actual <> 3 INSERT INTO @Failure VALUES (N'Batch statuses', CONCAT(N'expected 3, found ', @Actual));

SELECT @Actual = COUNT(*) FROM [reference].[AcademicTerm];
IF @Actual <> 10 INSERT INTO @Failure VALUES (N'Academic terms', CONCAT(N'expected 10, found ', @Actual));

SELECT @Actual = COUNT(*) FROM [reference].[ProgramCrosswalk];
IF @Actual <> 9 INSERT INTO @Failure VALUES (N'Program crosswalk', CONCAT(N'expected 9, found ', @Actual));

SELECT @Actual = COUNT(*) FROM [reference].[ExceptionReason] WHERE [IsActive] = 1;
IF @Actual <> 16 INSERT INTO @Failure VALUES (N'Exception reasons', CONCAT(N'expected 16, found ', @Actual));

SELECT @Actual = COUNT(*) FROM [reference].[MatchRule] WHERE [IsAutoMatchEligible] = 1;
IF @Actual <> 3 INSERT INTO @Failure VALUES (N'Automatic match rules', CONCAT(N'expected 3, found ', @Actual));

SELECT @Actual = COUNT(*) FROM [reference].[ExceptionStatusTransition];
IF @Actual <> 18 INSERT INTO @Failure VALUES (N'Exception transitions', CONCAT(N'expected 18, found ', @Actual));

SELECT @Actual = COUNT(*) FROM [reference].[PipelineStep];
IF @Actual <> 8 INSERT INTO @Failure VALUES (N'Pipeline steps', CONCAT(N'expected 8, found ', @Actual));

SELECT @Actual = COUNT(*) FROM [dq].[Rule] WHERE [IsActive] = 1;
IF @Actual <> 16 INSERT INTO @Failure VALUES (N'Data-quality rules', CONCAT(N'expected 16, found ', @Actual));

-- Every rule names a check procedure that exists, so no active rule is silently never run.
SELECT @Actual = COUNT(*) FROM [dq].[Rule] AS r WHERE r.[IsActive] = 1 AND OBJECT_ID(r.[CheckProcedure], N'P') IS NULL;
IF @Actual <> 0 INSERT INTO @Failure VALUES (N'Data-quality check procedures', CONCAT(@Actual, N' active rules name a missing procedure'));

-- Simulator data ----------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [SourceSystems].[SlateSim].[Application])
    INSERT INTO @Failure VALUES (N'Slate-Sim data', N'no applications; run make seed');
IF NOT EXISTS (SELECT 1 FROM [SourceSystems].[J1Sim].[Enrollment])
    INSERT INTO @Failure VALUES (N'J1-Sim data', N'no enrollments; run make seed');
IF NOT EXISTS (SELECT 1 FROM [SourceSystems].[DirectorySim].[DirectoryAccount])
    INSERT INTO @Failure VALUES (N'Directory-Sim data', N'no accounts; run make seed');

-- Cross-database agreement: the SIS calendar and catalog must match governed reference data.
SELECT @Actual = COUNT(*)
FROM (
    SELECT t.[TermCode], t.[TermName], t.[AcademicYear], t.[StartDate], t.[CensusDate], t.[EndDate], t.[IsOpenForAdmission]
    FROM [reference].[AcademicTerm] AS t
    EXCEPT
    SELECT j.[TermCode], j.[TermName], j.[AcademicYear], j.[StartDate], j.[CensusDate], j.[EndDate], j.[IsOpenForAdmission]
    FROM [SourceSystems].[J1Sim].[AcademicTerm] AS j
) AS mismatch;
IF @Actual <> 0
    INSERT INTO @Failure VALUES (N'Term calendar agreement', CONCAT(@Actual, N' reference terms differ from J1-Sim'));

SELECT @Actual = COUNT(*)
FROM [reference].[ProgramCrosswalk] AS pc
LEFT JOIN [SourceSystems].[J1Sim].[AcademicProgram] AS p
    ON pc.[J1ProgramCode] = p.[ProgramCode]
   AND pc.[IsActive] = p.[IsActive]
   AND pc.[CipCode] = p.[CipCode]
WHERE p.[ProgramCode] IS NULL;
IF @Actual <> 0
    INSERT INTO @Failure VALUES (N'Program catalog agreement', CONCAT(@Actual, N' crosswalk rows have no matching J1-Sim program'));

-- Edge cases (identifiers documented in pipelines/campus_ops/generators/edge_cases.py) ---
SELECT @Actual = COUNT(*)
FROM [SourceSystems].[J1Sim].[Person] AS p
WHERE p.[IdNumber] IN (9000001, 9000002);
IF @Actual <> 2 INSERT INTO @Failure VALUES (N'Edge case DUPLICATE_SIS_PERSON', N'expected SIS people 9000001 and 9000002');

SELECT @Actual = COUNT(*)
FROM [SourceSystems].[SlateSim].[ContactPoint] AS cp
INNER JOIN [SourceSystems].[SlateSim].[Person] AS sp ON cp.[PersonId] = sp.[PersonId]
INNER JOIN [SourceSystems].[J1Sim].[Person] AS jp
    ON cp.[ContactValue] = jp.[Email]
   AND sp.[BirthDate] = jp.[BirthDate]
WHERE sp.[PersonId] = '5E1A7E00-0000-4000-8000-000000000011'
  AND cp.[ContactType] = 'EMAIL';
IF @Actual <> 2 INSERT INTO @Failure VALUES (N'Edge case AMBIGUOUS_MATCH', CONCAT(N'expected 2 email+DOB candidates, found ', @Actual));

IF NOT EXISTS (
    SELECT 1
    FROM [SourceSystems].[SlateSim].[Application] AS a
    WHERE a.[ApplicationId] = '5E1A7E00-0000-4000-8000-000000000022'
      AND NOT EXISTS (
          SELECT 1 FROM [SourceSystems].[SlateSim].[ApplicationProgram] AS ap WHERE ap.[ApplicationId] = a.[ApplicationId]
      )
)
    INSERT INTO @Failure VALUES (N'Edge case MISSING_PROGRAM', N'application without program choice not found');

IF NOT EXISTS (
    SELECT 1
    FROM [SourceSystems].[SlateSim].[Application] AS a
    WHERE a.[ApplicationId] = '5E1A7E00-0000-4000-8000-000000000032'
      AND NOT EXISTS (SELECT 1 FROM [reference].[AcademicTerm] AS t WHERE t.[TermCode] = a.[EntryTermCode])
)
    INSERT INTO @Failure VALUES (N'Edge case INVALID_TERM', N'application with unknown entry term not found');

IF NOT EXISTS (
    SELECT 1
    FROM [SourceSystems].[SlateSim].[ContactPoint] AS cp
    WHERE cp.[PersonId] = '5E1A7E00-0000-4000-8000-000000000041'
      AND cp.[ContactType] = 'EMAIL'
      AND cp.[ContactValue] LIKE '%@@%'
)
    INSERT INTO @Failure VALUES (N'Edge case MALFORMED_EMAIL', N'malformed applicant email not found');

IF NOT EXISTS (
    SELECT 1
    FROM [SourceSystems].[DirectorySim].[DirectoryAccount] AS da
    WHERE da.[EmployeeId] = '9000099'
      AND da.[AccountType] = 'STUDENT'
      AND NOT EXISTS (SELECT 1 FROM [SourceSystems].[J1Sim].[Person] AS p WHERE p.[IdNumber] = 9000099)
)
    INSERT INTO @Failure VALUES (N'Edge case ORPHAN_DIRECTORY_ACCOUNT', N'orphan student account not found');

-- Landing batch control round trip, rolled back so no audit rows remain -----------------
DECLARE @BatchId BIGINT;
DECLARE @SecondBatchId BIGINT;
DECLARE @Watermark DATETIME2 (3);
DECLARE @NextWatermark DATETIME2 (3);
DECLARE @ReachedWatermark DATETIME2 (3);

BEGIN TRANSACTION;

EXEC [landing].[usp_BeginLandingBatch]
    @SourceSystemCode = 'SLATE_SIM',
    @BatchId = @BatchId OUTPUT,
    @PreviousWatermarkUtc = @Watermark OUTPUT;

-- A watermark can never move backwards, so the round trip reaches one minute past the last
-- successful load (or a fixed date on a fresh platform).
SET @ReachedWatermark = DATEADD(MINUTE, 1, COALESCE(@Watermark, CAST('2026-09-01T12:00:00' AS DATETIME2 (3))));

EXEC [landing].[usp_EndLandingBatch]
    @BatchId = @BatchId,
    @Succeeded = 1,
    @SourceWatermarkUtc = @ReachedWatermark,
    @RowsRead = 10,
    @RowsInserted = 7,
    @RowsUnchanged = 2,
    @RowsRejected = 1;

EXEC [landing].[usp_BeginLandingBatch]
    @SourceSystemCode = 'SLATE_SIM',
    @BatchId = @SecondBatchId OUTPUT,
    @PreviousWatermarkUtc = @NextWatermark OUTPUT;

IF NOT EXISTS (
    SELECT 1 FROM [audit].[BatchRun] AS br
    WHERE br.[BatchId] = @BatchId AND br.[BatchStatusCode] = 'SUCCEEDED' AND br.[RowsRead] = 10
)
    INSERT INTO @Failure VALUES (N'Landing batch round trip', N'first batch was not recorded as SUCCEEDED with its counts');

IF @NextWatermark IS NULL OR @NextWatermark < @ReachedWatermark
    INSERT INTO @Failure VALUES (N'Landing watermark', N'next batch did not start from the last successful watermark');

ROLLBACK TRANSACTION;

-- Table variables survive the rollback, so failures recorded above are still reported.
IF EXISTS (SELECT 1 FROM @Failure)
BEGIN
    SELECT f.[CheckName], f.[Detail] FROM @Failure AS f;
    THROW 50090, N'Smoke test failed; see the checks listed above.', 1;
END;

PRINT N'Smoke test passed.';
