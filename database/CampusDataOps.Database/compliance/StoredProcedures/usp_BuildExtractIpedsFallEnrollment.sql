-- IPEDS-aligned Fall Enrollment (educational simulation) for one fall term.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractIpedsFallEnrollment]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Included INT;
    DECLARE @Message NVARCHAR (400);

    IF NOT EXISTS (
        SELECT 1 FROM [reference].[AcademicTerm] AS t WHERE t.[TermCode] = @ReportingPeriod AND t.[TermType] = 'FALL'
    )
        THROW 52131, N'The IPEDS Fall Enrollment extract needs a fall term.', 1;

    SELECT @CensusSnapshotId = s.[CensusSnapshotId], @Included = s.[IncludedCount]
    FROM [compliance].[CensusSnapshot] AS s
    INNER JOIN [compliance].[CensusRuleVersion] AS r
        ON s.[RuleVersion] = r.[RuleVersion]
       AND r.[IsCurrent] = 1
    WHERE s.[TermCode] = @ReportingPeriod;

    IF @CensusSnapshotId IS NULL
    BEGIN
        SET @Message = CONCAT(N'Term ', @ReportingPeriod, N' has no census snapshot for the current rule version.');
        THROW 52130, @Message, 1;
    END;

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, CONCAT(
        N'ReportingPeriod,Section,AttendanceStatus,StudentCategory,ResidencyGroup,AgeBand,',
        N'Headcount'
    ));

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (
            ORDER BY f.[Section], f.[AttendanceStatus], f.[StudentCategory], f.[ResidencyGroup], f.[AgeBand]
        ) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), f.[ReportingPeriod])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), f.[Section])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), f.[AttendanceStatus])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), f.[StudentCategory])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), f.[ResidencyGroup])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), f.[AgeBand])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), f.[Headcount]))
        ) AS [LineText]
    FROM [compliance].[vw_IPEDS_FallEnrollment] AS f
    WHERE f.[ReportingPeriod] = @ReportingPeriod;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'TOTAL_HEADCOUNT', 'RECONCILIATION', '=',
            @Included,
            (
                SELECT ISNULL(SUM(f.[Headcount]), 0)
                FROM [compliance].[vw_IPEDS_FallEnrollment] AS f
                WHERE f.[ReportingPeriod] = @ReportingPeriod AND f.[Section] = 'TOTAL'
            ),
            NULL
        ),
        (
            'PART_A_SUM', 'SUBTOTAL', '=',
            @Included,
            (
                SELECT ISNULL(SUM(f.[Headcount]), 0)
                FROM [compliance].[vw_IPEDS_FallEnrollment] AS f
                WHERE f.[ReportingPeriod] = @ReportingPeriod AND f.[Section] = 'PART_A'
            ),
            NULL
        ),
        (
            'PART_B_SUM', 'SUBTOTAL', '=',
            @Included,
            (
                SELECT ISNULL(SUM(f.[Headcount]), 0)
                FROM [compliance].[vw_IPEDS_FallEnrollment] AS f
                WHERE f.[ReportingPeriod] = @ReportingPeriod AND f.[Section] = 'PART_B'
            ),
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
