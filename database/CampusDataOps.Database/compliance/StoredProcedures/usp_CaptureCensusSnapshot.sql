-- Captures the immutable census snapshot of one term under the current rule version (ADR-003,
-- docs/specifications/report-catalog.md R1). Capturing again returns the existing snapshot.
-- Refused before the census date, while a nightly run is RUNNING, or before any nightly run
-- has succeeded. @AsOfDate exists for tests; it defaults to today (UTC) and may not be later.
CREATE PROCEDURE [compliance].[usp_CaptureCensusSnapshot]
    @TermCode         VARCHAR (10),
    @AsOfDate         DATE = NULL,
    @CensusSnapshotId INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
    DECLARE @CensusDate DATE;
    DECLARE @RuleVersion VARCHAR (20);
    DECLARE @FullTimeMinCredits DECIMAL (4, 1);
    DECLARE @SourceBatchId BIGINT;
    DECLARE @SourceWatermarkUtc DATETIME2 (3);
    DECLARE @Message NVARCHAR (400);
    DECLARE @Rows [compliance].[CensusRowList];

    SET @AsOfDate = ISNULL(@AsOfDate, @Today);
    IF @AsOfDate > @Today
        THROW 52001, N'@AsOfDate cannot be in the future.', 1;

    SET @CensusDate = (SELECT t.[CensusDate] FROM [reference].[AcademicTerm] AS t WHERE t.[TermCode] = @TermCode);
    IF @CensusDate IS NULL
    BEGIN
        SET @Message = CONCAT(N'Unknown term ', ISNULL(@TermCode, N'NULL'), N'.');
        THROW 52002, @Message, 1;
    END;

    IF @AsOfDate < @CensusDate
    BEGIN
        SET @Message = CONCAT(
            N'Term ', @TermCode, N' reaches census on ', CONVERT(CHAR (10), @CensusDate, 23), N'; nothing to capture yet.'
        );
        THROW 52003, @Message, 1;
    END;

    SELECT @RuleVersion = r.[RuleVersion], @FullTimeMinCredits = r.[FullTimeMinCredits]
    FROM [compliance].[CensusRuleVersion] AS r
    WHERE r.[IsCurrent] = 1;
    IF @RuleVersion IS NULL
        THROW 52004, N'No current census rule version.', 1;

    SET @CensusSnapshotId = (
        SELECT s.[CensusSnapshotId]
        FROM [compliance].[CensusSnapshot] AS s
        WHERE s.[TermCode] = @TermCode AND s.[RuleVersion] = @RuleVersion
    );
    IF @CensusSnapshotId IS NOT NULL
    BEGIN
        PRINT CONCAT(N'Term ', @TermCode, N' already has snapshot ', @CensusSnapshotId, N' for rule version ', @RuleVersion, N'.');
        RETURN;
    END;

    IF EXISTS (
        SELECT 1 FROM [audit].[BatchRun] AS br
        WHERE br.[ProcessName] = 'NIGHTLY_INTEGRATION' AND br.[BatchStatusCode] = 'RUNNING'
    )
        THROW 52005, N'A nightly integration run is RUNNING; capture after it finishes.', 1;

    SELECT TOP (1) @SourceBatchId = br.[BatchId]
    FROM [audit].[BatchRun] AS br
    WHERE br.[ProcessName] = 'NIGHTLY_INTEGRATION' AND br.[BatchStatusCode] = 'SUCCEEDED'
    ORDER BY br.[BatchId] DESC;
    IF @SourceBatchId IS NULL
        THROW 52006, N'No nightly integration run has succeeded; there is no staged data to capture.', 1;

    SET @SourceWatermarkUtc = (
        SELECT MAX(child.[SourceWatermarkUtc])
        FROM [audit].[BatchRun] AS child
        WHERE child.[ParentBatchId] = @SourceBatchId AND child.[SourceSystemCode] = 'J1_SIM'
    );

    INSERT INTO @Rows (
        [IdNumber], [ProgramCode], [EntryTermCode], [StudentStatus], [ResidencyCode], [CensusCredits], [CountedSections],
        [AttendanceIntensity], [EntryStatus], [AgeAtCensus], [IsCensusIncluded], [ExclusionReason]
    )
    SELECT
        c.[IdNumber], c.[ProgramCode], c.[EntryTermCode], c.[StudentStatus], c.[ResidencyCode], c.[CensusCredits],
        CAST(c.[CountedSections] AS SMALLINT) AS [CountedSections],
        CASE
            WHEN x.[IsIncluded] = 0 THEN NULL
            WHEN c.[CensusCredits] >= @FullTimeMinCredits THEN 'FULL_TIME'
            ELSE 'PART_TIME'
        END AS [AttendanceIntensity],
        c.[EntryStatus],
        CAST(c.[AgeAtCensus] AS TINYINT) AS [AgeAtCensus],
        x.[IsIncluded],
        CASE
            WHEN c.[HasStudentRecord] = 0 THEN 'NO_STUDENT_RECORD'
            WHEN c.[CensusCredits] > 0 THEN NULL
            WHEN c.[SectionsRegisteredByCensus] > 0 THEN 'DROPPED_BEFORE_CENSUS'
            ELSE 'REGISTERED_AFTER_CENSUS'
        END AS [ExclusionReason]
    FROM [core].[vw_StudentTermCensus] AS c
    CROSS APPLY ( -- noqa: ST05
        SELECT CAST(CASE WHEN c.[HasStudentRecord] = 1 AND c.[CensusCredits] > 0 THEN 1 ELSE 0 END AS BIT) AS [IsIncluded]
    ) AS x
    WHERE c.[TermCode] = @TermCode;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO [compliance].[CensusSnapshot] (
            [TermCode], [CensusDate], [RuleVersion], [SourceBatchId], [SourceWatermarkUtc], [CapturedAtUtc], [CapturedBy],
            [PopulationCount], [IncludedCount], [FullTimeCount], [CreditTotal], [RowChecksum]
        )
        SELECT
            @TermCode AS [TermCode],
            @CensusDate AS [CensusDate],
            @RuleVersion AS [RuleVersion],
            @SourceBatchId AS [SourceBatchId],
            @SourceWatermarkUtc AS [SourceWatermarkUtc],
            SYSUTCDATETIME() AS [CapturedAtUtc],
            ORIGINAL_LOGIN() AS [CapturedBy],
            COUNT(*) AS [PopulationCount],
            ISNULL(SUM(CASE WHEN r.[IsCensusIncluded] = 1 THEN 1 ELSE 0 END), 0) AS [IncludedCount],
            ISNULL(SUM(CASE WHEN r.[AttendanceIntensity] = 'FULL_TIME' THEN 1 ELSE 0 END), 0) AS [FullTimeCount],
            ISNULL(SUM(CASE WHEN r.[IsCensusIncluded] = 1 THEN r.[CensusCredits] ELSE 0 END), 0) AS [CreditTotal],
            [compliance].[fn_CensusRowsChecksum](@Rows) AS [RowChecksum]
        FROM @Rows AS r;

        SET @CensusSnapshotId = CAST(SCOPE_IDENTITY() AS INT);

        INSERT INTO [compliance].[CensusSnapshotEnrollment] (
            [CensusSnapshotId], [IdNumber], [ProgramCode], [EntryTermCode], [StudentStatus], [ResidencyCode], [CensusCredits],
            [CountedSections], [AttendanceIntensity], [EntryStatus], [AgeAtCensus], [IsCensusIncluded], [ExclusionReason]
        )
        SELECT
            @CensusSnapshotId AS [CensusSnapshotId], r.[IdNumber], r.[ProgramCode], r.[EntryTermCode], r.[StudentStatus],
            r.[ResidencyCode], r.[CensusCredits], r.[CountedSections], r.[AttendanceIntensity], r.[EntryStatus],
            r.[AgeAtCensus], r.[IsCensusIncluded], r.[ExclusionReason]
        FROM @Rows AS r;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
