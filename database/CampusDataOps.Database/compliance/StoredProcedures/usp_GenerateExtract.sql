-- Generates one extract run (docs/specifications/extract-controls.md): checks the caller against
-- the type's access role, resolves the reporting period, records the run, calls the type's
-- builder, stores the line count and the SHA-256 of the exact file content, validates the
-- control totals and closes the run SUCCEEDED, all in one transaction. A builder error leaves
-- the run FAILED with its message and no rows. Every attempt is audited.
-- Content: lines joined by LF plus a final LF, encoded UTF-8 without a byte-order mark.
CREATE PROCEDURE [compliance].[usp_GenerateExtract]
    @ExtractTypeCode VARCHAR (30),
    @ReportingPeriod VARCHAR (20) = NULL,
    @ExtractRunId    BIGINT       = NULL OUTPUT,
    @ReturnSummary   BIT          = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Today DATE = CONVERT(DATE, SYSUTCDATETIME());
    DECLARE @ObjectName NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @PeriodType VARCHAR (15);
    DECLARE @AccessRoleName NVARCHAR (128);
    DECLARE @IsPrivileged BIT;
    DECLARE @GeneratorVersion VARCHAR (10);
    DECLARE @PeriodStartDate DATE;
    DECLARE @AsOfDate DATE;
    DECLARE @FirstYear INT;
    DECLARE @SourceBatchId BIGINT;
    DECLARE @CensusSnapshotId INT;
    DECLARE @LineCount INT;
    DECLARE @Content NVARCHAR (MAX);
    DECLARE @Message NVARCHAR (400);

    SELECT
        @PeriodType = t.[PeriodType], @AccessRoleName = t.[AccessRoleName], @IsPrivileged = t.[IsPrivileged],
        @GeneratorVersion = t.[GeneratorVersion]
    FROM [reference].[ExtractType] AS t
    WHERE t.[ExtractTypeCode] = @ExtractTypeCode;

    IF @PeriodType IS NULL
    BEGIN
        SET @Message = CONCAT(N'Unknown extract type ', ISNULL(@ExtractTypeCode, N'NULL'), N'.');
        THROW 52101, @Message, 1;
    END;

    IF NOT (IS_MEMBER(@AccessRoleName) = 1 OR IS_MEMBER(N'role_integration_service') = 1 OR IS_MEMBER(N'db_owner') = 1)
    BEGIN
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = 'EXTRACT_GENERATE', @ObjectName = @ObjectName, @IsPrivileged = @IsPrivileged, @IsAllowed = 0,
            @SubjectKey = @ExtractTypeCode, @Detail = N'REFUSED: caller is not in the extract type''s access role';
        SET @Message = CONCAT(N'Generating ', @ExtractTypeCode, N' requires membership of ', @AccessRoleName, N'.');
        THROW 52102, @Message, 1;
    END;

    IF @PeriodType = 'NONE'
    BEGIN
        SET @PeriodStartDate = @Today;
        SET @ReportingPeriod = CONVERT(CHAR (10), @Today, 23);
    END
    ELSE IF @PeriodType = 'AS_OF_DATE'
    BEGIN
        SET @AsOfDate = ISNULL(TRY_CONVERT(DATE, @ReportingPeriod, 23), CASE WHEN @ReportingPeriod IS NULL THEN @Today END);
        IF @AsOfDate IS NULL OR @AsOfDate > @Today
            THROW 52103, N'The reporting period must be a date (YYYY-MM-DD) that is not in the future.', 1;
        SET @PeriodStartDate = @AsOfDate;
        SET @ReportingPeriod = CONVERT(CHAR (10), @AsOfDate, 23);
    END
    ELSE IF @PeriodType = 'TERM'
        SET @PeriodStartDate = (SELECT t.[StartDate] FROM [reference].[AcademicTerm] AS t WHERE t.[TermCode] = @ReportingPeriod)
    ELSE IF @PeriodType = 'ACADEMIC_YEAR' AND @ReportingPeriod LIKE '[12][0-9][0-9][0-9]-[12][0-9][0-9][0-9]'
    BEGIN
        SET @FirstYear = CONVERT(INT, LEFT(@ReportingPeriod, 4));
        IF CONVERT(INT, RIGHT(@ReportingPeriod, 4)) = @FirstYear + 1
            SET @PeriodStartDate = DATEFROMPARTS(@FirstYear, 7, 1);
    END;

    IF @PeriodStartDate IS NULL
    BEGIN
        SET @Message = CONCAT(
            N'Invalid reporting period ', ISNULL(@ReportingPeriod, N'NULL'), N' for ', @ExtractTypeCode,
            N': expected a governed term code or an academic year such as 2025-2026.'
        );
        THROW 52103, @Message, 1;
    END;

    IF EXISTS (
        SELECT 1 FROM [audit].[BatchRun] AS br
        WHERE br.[ProcessName] = 'NIGHTLY_INTEGRATION' AND br.[BatchStatusCode] = 'RUNNING'
    )
        THROW 52105, N'A nightly integration run is RUNNING; generate extracts after it finishes.', 1;

    SELECT TOP (1) @SourceBatchId = br.[BatchId]
    FROM [audit].[BatchRun] AS br
    WHERE br.[ProcessName] = 'NIGHTLY_INTEGRATION' AND br.[BatchStatusCode] = 'SUCCEEDED'
    ORDER BY br.[BatchId] DESC;
    IF @SourceBatchId IS NULL
        THROW 52104, N'No nightly integration run has succeeded; there is nothing to report.', 1;

    EXEC [audit].[usp_LogAccessEvent]
        @EventType = 'EXTRACT_GENERATE', @ObjectName = @ObjectName, @IsPrivileged = @IsPrivileged, @IsAllowed = 1,
        @SubjectKey = @ExtractTypeCode, @Detail = @ReportingPeriod;

    INSERT INTO [compliance].[ExtractRun] (
        [ExtractTypeCode], [ReportingPeriod], [PeriodStartDate], [ParametersJson], [SourceBatchId], [ExtractStatusCode],
        [GeneratorVersion]
    )
    VALUES (
        @ExtractTypeCode, @ReportingPeriod, @PeriodStartDate,
        (SELECT @ExtractTypeCode AS [extract_type], @ReportingPeriod AS [reporting_period] FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        @SourceBatchId, 'GENERATING', @GeneratorVersion
    );
    SET @ExtractRunId = CONVERT(BIGINT, SCOPE_IDENTITY());

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ExtractTypeCode = 'ENROLLMENT_CENSUS'
            EXEC [compliance].[usp_BuildExtractEnrollmentCensus] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'AID_PACKAGING'
            EXEC [compliance].[usp_BuildExtractAidPackaging] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'ACCOUNT_AGING'
            EXEC [compliance].[usp_BuildExtractAccountAging] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'ACADEMIC_PROGRESS'
            EXEC [compliance].[usp_BuildExtractAcademicProgress] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'EXCEPTION_WORKLIST'
            EXEC [compliance].[usp_BuildExtractExceptionWorklist] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'LEADERSHIP_KPI'
            EXEC [compliance].[usp_BuildExtractLeadershipKpi] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'DQ_SCORECARD'
            EXEC [compliance].[usp_BuildExtractDqScorecard] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'IPEDS_FE'
            EXEC [compliance].[usp_BuildExtractIpedsFallEnrollment] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'IPEDS_E12'
            EXEC [compliance].[usp_BuildExtractIpeds12MonthEnrollment] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'IPEDS_C'
            EXEC [compliance].[usp_BuildExtractIpedsCompletions] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE IF @ExtractTypeCode = 'IPEDS_SFA'
            EXEC [compliance].[usp_BuildExtractIpedsStudentFinancialAid] @ExtractRunId, @ReportingPeriod, @CensusSnapshotId OUTPUT;
        ELSE
        BEGIN
            SET @Message = CONCAT(N'Extract type ', @ExtractTypeCode, N' has no builder.');
            THROW 52106, @Message, 1;
        END;

        SELECT
            @LineCount = COUNT(*),
            @Content = STRING_AGG(CONVERT(NVARCHAR (MAX), r.[LineText]), NCHAR(10)) WITHIN GROUP (ORDER BY r.[LineNumber])
        FROM [compliance].[ExtractRow] AS r
        WHERE r.[ExtractRunId] = @ExtractRunId;

        IF @LineCount = 0
            THROW 52107, N'The builder wrote no header line.', 1;

        -- Every run gets a data-row count control, so prior-period thresholds can apply to it.
        INSERT INTO [compliance].[ExtractControlTotal] ([ExtractRunId], [ControlCode], [ControlKind], [ActualValue])
        VALUES (@ExtractRunId, 'DATA_ROW_COUNT', 'INFO', @LineCount - 1);

        UPDATE r
        SET r.[LineCount] = @LineCount,
            r.[DataRowCount] = @LineCount - 1,
            r.[CensusSnapshotId] = @CensusSnapshotId,
            r.[ContentSha256] = HASHBYTES(
                'SHA2_256', CONVERT(VARCHAR (MAX), CONCAT(@Content, NCHAR(10)) COLLATE Latin1_General_100_BIN2_UTF8) -- noqa: CP02
            )
        FROM [compliance].[ExtractRun] AS r
        WHERE r.[ExtractRunId] = @ExtractRunId;

        EXEC [compliance].[usp_ValidateExtractControlTotals] @ExtractRunId = @ExtractRunId;

        UPDATE r
        SET r.[ExtractStatusCode] = 'SUCCEEDED', r.[CompletedAtUtc] = SYSUTCDATETIME()
        FROM [compliance].[ExtractRun] AS r
        WHERE r.[ExtractRunId] = @ExtractRunId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        UPDATE r
        SET r.[ExtractStatusCode] = 'FAILED',
            r.[CompletedAtUtc] = SYSUTCDATETIME(),
            r.[ErrorMessage] = LEFT(CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()), 2048)
        FROM [compliance].[ExtractRun] AS r
        WHERE r.[ExtractRunId] = @ExtractRunId;

        THROW;
    END CATCH;

    IF @ReturnSummary = 1
        SELECT
            r.[ExtractRunId], r.[ExtractTypeCode], r.[ReportingPeriod], r.[DataRowCount], r.[ValidationStatusCode],
            r.[ApprovalStatusCode], LOWER(CONVERT(CHAR (64), r.[ContentSha256], 2)) AS [ContentSha256]
        FROM [compliance].[ExtractRun] AS r
        WHERE r.[ExtractRunId] = @ExtractRunId;
END;
