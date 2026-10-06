-- IPEDS-aligned 12-month Enrollment (educational simulation) for one academic year.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractIpeds12MonthEnrollment]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FallIncluded INT = (
        SELECT s.[IncludedCount]
        FROM [compliance].[CensusSnapshot] AS s
        INNER JOIN [compliance].[CensusRuleVersion] AS r
            ON s.[RuleVersion] = r.[RuleVersion]
           AND r.[IsCurrent] = 1
        INNER JOIN [reference].[AcademicTerm] AS t ON s.[TermCode] = t.[TermCode]
        WHERE t.[AcademicYear] = @ReportingPeriod AND t.[TermType] = 'FALL'
    );

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, N'ReportingPeriod,Section,AttendanceStatus,StudentCategory,Headcount,CreditHours');

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY m.[Section], m.[AttendanceStatus], m.[StudentCategory]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), m.[ReportingPeriod])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), m.[Section])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), m.[AttendanceStatus])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), m.[StudentCategory])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), m.[Headcount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), m.[CreditHours]))
        ) AS [LineText]
    FROM [compliance].[vw_IPEDS_12MonthEnrollment] AS m
    WHERE m.[ReportingPeriod] = @ReportingPeriod;

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
            (
                SELECT COUNT(DISTINCT e.[IdNumber]) FROM [core].[vw_Enrollment] AS e
                INNER JOIN [core].[vw_Term] AS t ON e.[TermCode] = t.[TermCode]
                WHERE t.[AcademicYear] = @ReportingPeriod AND e.[IsAttempted] = 1
            ),
            (
                SELECT ISNULL(SUM(m.[Headcount]), 0)
                FROM [compliance].[vw_IPEDS_12MonthEnrollment] AS m
                WHERE m.[ReportingPeriod] = @ReportingPeriod AND m.[Section] = 'TOTAL'
            ),
            NULL
        ),
        (
            'STATUS_SUM', 'SUBTOTAL', '=',
            (
                SELECT ISNULL(SUM(m.[Headcount]), 0)
                FROM [compliance].[vw_IPEDS_12MonthEnrollment] AS m
                WHERE m.[ReportingPeriod] = @ReportingPeriod AND m.[Section] = 'TOTAL'
            ),
            (
                SELECT ISNULL(SUM(m.[Headcount]), 0)
                FROM [compliance].[vw_IPEDS_12MonthEnrollment] AS m
                WHERE m.[ReportingPeriod] = @ReportingPeriod AND m.[Section] = 'BY_STATUS'
            ),
            NULL
        ),
        (
            'CREDIT_HOURS', 'RECONCILIATION', '=',
            (
                SELECT ISNULL(SUM(e.[CreditHours]), 0) FROM [core].[vw_Enrollment] AS e
                INNER JOIN [core].[vw_Term] AS t ON e.[TermCode] = t.[TermCode]
                WHERE t.[AcademicYear] = @ReportingPeriod AND e.[IsAttempted] = 1
            ),
            (
                SELECT ISNULL(SUM(m.[CreditHours]), 0)
                FROM [compliance].[vw_IPEDS_12MonthEnrollment] AS m
                WHERE m.[ReportingPeriod] = @ReportingPeriod AND m.[Section] = 'TOTAL'
            ),
            NULL
        ),
        (
            'TOTAL_AT_LEAST_FALL_CENSUS', 'RULE', '>=',
            @FallIncluded,
            (
                SELECT ISNULL(SUM(m.[Headcount]), 0)
                FROM [compliance].[vw_IPEDS_12MonthEnrollment] AS m
                WHERE m.[ReportingPeriod] = @ReportingPeriod AND m.[Section] = 'TOTAL'
            ),
            CASE WHEN @FallIncluded IS NULL THEN N'The fall term has no census snapshot; the rule could not be checked.' END
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
