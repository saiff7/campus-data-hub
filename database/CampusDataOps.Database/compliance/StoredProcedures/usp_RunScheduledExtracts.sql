-- Runs one Agent schedule (docs/specifications/extract-controls.md): the CENSUS schedule first
-- captures a snapshot for every term whose census date has passed and that has none under the
-- current rule version; then every extract listed in reference.ExtractSchedule is generated for
-- the period its PeriodRule resolves from @AsOfDate (default today, UTC). One failure does not
-- stop the others; the procedure raises 52140 at the end if anything failed, so the Agent step
-- fails visibly. Returns one row per attempted capture or extract.
CREATE PROCEDURE [compliance].[usp_RunScheduledExtracts]
    @ScheduleCode VARCHAR (10),
    @AsOfDate     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CONVERT(DATE, SYSUTCDATETIME());
    DECLARE @StartedAtUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @AcademicYearStart INT;
    DECLARE @CurrentAcademicYear VARCHAR (9);
    DECLARE @LastCompletedAcademicYear VARCHAR (9);
    DECLARE @CurrentTerm VARCHAR (10);
    DECLARE @WorkId INT = 0;
    DECLARE @ItemType VARCHAR (30);
    DECLARE @Period VARCHAR (20);
    DECLARE @RunId BIGINT;
    DECLARE @SnapshotId INT;
    DECLARE @Failures INT;
    DECLARE @Message NVARCHAR (400);
    DECLARE @Work TABLE (
        [WorkId]          INT          IDENTITY (1, 1) NOT NULL PRIMARY KEY,
        [ItemType]        VARCHAR (30) NOT NULL,
        [ReportingPeriod] VARCHAR (20) NULL,
        [ExtractRunId]    BIGINT       NULL,
        [Outcome]         VARCHAR (10) NULL,
        [Message]         NVARCHAR (400) NULL
    );

    SET @AsOfDate = ISNULL(@AsOfDate, @Today);
    IF @AsOfDate > @Today
        THROW 52141, N'@AsOfDate cannot be in the future.', 1;
    IF NOT EXISTS (SELECT 1 FROM [reference].[ExtractSchedule] AS s WHERE s.[ScheduleCode] = @ScheduleCode)
        THROW 52142, N'Unknown schedule; expected DAILY, WEEKLY or CENSUS.', 1;

    SET @AcademicYearStart = YEAR(@AsOfDate) - CASE WHEN MONTH(@AsOfDate) < 7 THEN 1 ELSE 0 END;
    SET @CurrentAcademicYear = CONCAT(@AcademicYearStart, '-', @AcademicYearStart + 1);
    SET @LastCompletedAcademicYear = CONCAT(@AcademicYearStart - 1, '-', @AcademicYearStart);
    SET @CurrentTerm = (
        SELECT TOP (1) t.[TermCode] FROM [reference].[AcademicTerm] AS t WHERE t.[StartDate] <= @AsOfDate ORDER BY t.[StartDate] DESC
    );

    IF @ScheduleCode = 'CENSUS'
        INSERT INTO @Work ([ItemType], [ReportingPeriod])
        SELECT 'CENSUS_SNAPSHOT' AS [ItemType], t.[TermCode] AS [ReportingPeriod]
        FROM [reference].[AcademicTerm] AS t
        WHERE t.[CensusDate] <= @AsOfDate
          AND NOT EXISTS (
              SELECT 1
              FROM [compliance].[CensusSnapshot] AS s
              INNER JOIN [compliance].[CensusRuleVersion] AS r
                  ON s.[RuleVersion] = r.[RuleVersion]
                 AND r.[IsCurrent] = 1
              WHERE s.[TermCode] = t.[TermCode]
          )
        ORDER BY t.[StartDate];

    -- Snapshots first, so NEW_SNAPSHOT_* rules below see the terms captured in this run.
    WHILE 1 = 1
    BEGIN
        SELECT TOP (1) @WorkId = w.[WorkId], @Period = w.[ReportingPeriod]
        FROM @Work AS w
        WHERE w.[WorkId] > @WorkId AND w.[ItemType] = 'CENSUS_SNAPSHOT'
        ORDER BY w.[WorkId];
        IF @@ROWCOUNT = 0
            BREAK;

        BEGIN TRY
            SET @SnapshotId = NULL;
            EXEC [compliance].[usp_CaptureCensusSnapshot] @TermCode = @Period, @CensusSnapshotId = @SnapshotId OUTPUT;
            UPDATE w SET w.[Outcome] = 'SUCCEEDED', w.[Message] = CONCAT(N'Snapshot ', @SnapshotId)
            FROM @Work AS w
            WHERE w.[WorkId] = @WorkId;
        END TRY
        BEGIN CATCH
            UPDATE w SET w.[Outcome] = 'FAILED', w.[Message] = LEFT(ERROR_MESSAGE(), 400) FROM @Work AS w WHERE w.[WorkId] = @WorkId;
        END CATCH;
    END;

    INSERT INTO @Work ([ItemType], [ReportingPeriod])
    SELECT x.[ExtractTypeCode], x.[ReportingPeriod]
    FROM (
        SELECT s.[ExtractTypeCode], s.[SortOrder], p.[ReportingPeriod], p.[PeriodOrder]
        FROM [reference].[ExtractSchedule] AS s
        CROSS APPLY (
            SELECT CONVERT(VARCHAR (20), CONVERT(CHAR (10), @AsOfDate, 23)) AS [ReportingPeriod], 0 AS [PeriodOrder]
            WHERE s.[PeriodRule] = 'TODAY'
            UNION ALL
            SELECT CONVERT(VARCHAR (20), NULL) AS [ReportingPeriod], 0 AS [PeriodOrder]
            WHERE s.[PeriodRule] = 'NONE'
            UNION ALL
            SELECT @CurrentAcademicYear AS [ReportingPeriod], 0 AS [PeriodOrder]
            WHERE s.[PeriodRule] = 'CURRENT_ACADEMIC_YEAR'
            UNION ALL
            SELECT @CurrentTerm AS [ReportingPeriod], 0 AS [PeriodOrder]
            WHERE s.[PeriodRule] = 'CURRENT_TERM' AND @CurrentTerm IS NOT NULL
            UNION ALL
            SELECT @LastCompletedAcademicYear AS [ReportingPeriod], 0 AS [PeriodOrder]
            WHERE s.[PeriodRule] = 'LAST_COMPLETED_ACADEMIC_YEAR'
              AND NOT EXISTS (
                  SELECT 1 FROM [compliance].[ExtractRun] AS er
                  WHERE er.[ExtractTypeCode] = s.[ExtractTypeCode] AND er.[ReportingPeriod] = @LastCompletedAcademicYear
                    AND er.[ExtractStatusCode] = 'SUCCEEDED'
              )
            UNION ALL
            SELECT cs.[TermCode] AS [ReportingPeriod], DATEDIFF(DAY, '2000-01-01', t.[StartDate]) AS [PeriodOrder]
            FROM [compliance].[CensusSnapshot] AS cs
            INNER JOIN [compliance].[CensusRuleVersion] AS r
                ON cs.[RuleVersion] = r.[RuleVersion]
               AND r.[IsCurrent] = 1
            INNER JOIN [reference].[AcademicTerm] AS t ON cs.[TermCode] = t.[TermCode]
            WHERE (s.[PeriodRule] = 'NEW_SNAPSHOT_TERMS' OR (s.[PeriodRule] = 'NEW_SNAPSHOT_FALL_TERMS' AND t.[TermType] = 'FALL'))
              AND NOT EXISTS (
                  SELECT 1 FROM [compliance].[ExtractRun] AS er
                  WHERE er.[ExtractTypeCode] = s.[ExtractTypeCode] AND er.[ReportingPeriod] = cs.[TermCode]
                    AND er.[ExtractStatusCode] = 'SUCCEEDED'
              )
        ) AS p
        WHERE s.[ScheduleCode] = @ScheduleCode
    ) AS x
    ORDER BY x.[SortOrder], x.[PeriodOrder];

    WHILE 1 = 1
    BEGIN
        SELECT TOP (1) @WorkId = w.[WorkId], @ItemType = w.[ItemType], @Period = w.[ReportingPeriod]
        FROM @Work AS w
        WHERE w.[WorkId] > @WorkId
        ORDER BY w.[WorkId];
        IF @@ROWCOUNT = 0
            BREAK;

        BEGIN TRY
            SET @RunId = NULL;
            EXEC [compliance].[usp_GenerateExtract]
                @ExtractTypeCode = @ItemType, @ReportingPeriod = @Period, @ExtractRunId = @RunId OUTPUT, @ReturnSummary = 0;
            UPDATE w
            SET w.[ExtractRunId] = r.[ExtractRunId], w.[ReportingPeriod] = r.[ReportingPeriod], w.[Outcome] = 'SUCCEEDED',
                w.[Message] = CONCAT(N'Validation ', r.[ValidationStatusCode])
            FROM @Work AS w
            CROSS JOIN [compliance].[ExtractRun] AS r
            WHERE w.[WorkId] = @WorkId AND r.[ExtractRunId] = @RunId;
        END TRY
        BEGIN CATCH
            -- OUTPUT parameters are not returned when a procedure raises an error; find the FAILED run.
            UPDATE w
            SET w.[Outcome] = 'FAILED',
                w.[ExtractRunId] = (
                    SELECT MAX(r.[ExtractRunId]) FROM [compliance].[ExtractRun] AS r
                    WHERE r.[ExtractTypeCode] = @ItemType AND r.[ExtractStatusCode] = 'FAILED' AND r.[GeneratedAtUtc] >= @StartedAtUtc
                ),
                w.[Message] = LEFT(ERROR_MESSAGE(), 400)
            FROM @Work AS w
            WHERE w.[WorkId] = @WorkId;
        END CATCH;
    END;

    SELECT w.[WorkId], w.[ItemType], w.[ReportingPeriod], w.[ExtractRunId], w.[Outcome], w.[Message]
    FROM @Work AS w
    ORDER BY w.[WorkId];

    SET @Failures = (SELECT COUNT(*) FROM @Work AS w WHERE w.[Outcome] = 'FAILED');
    IF @Failures > 0
    BEGIN
        SET @Message = CONCAT(
            @Failures, N' item(s) of schedule ', @ScheduleCode, N' failed; see the result set and compliance.ExtractRun.'
        );
        THROW 52140, @Message, 1;
    END;
END;
