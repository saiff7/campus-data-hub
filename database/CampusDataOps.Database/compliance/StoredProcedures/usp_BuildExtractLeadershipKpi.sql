-- R6 Leadership KPIs for the terms of one academic year.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractLeadershipKpi]
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
    VALUES (@ExtractRunId, 1, CONCAT(
        N'TermCode,AcademicYear,MeasureCode,MeasureName,Unit,OwnerDepartmentCode,',
        N'MeasureValue,DataStatus'
    ));

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY t.[StartDate], md.[SortOrder]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), k.[TermCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), k.[AcademicYear])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), k.[MeasureCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), k.[MeasureName])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), k.[Unit])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), k.[OwnerDepartmentCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), k.[MeasureValue])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), k.[DataStatus]))
        ) AS [LineText]
    FROM [reporting].[vw_LeadershipKPI] AS k
    INNER JOIN [reference].[AcademicTerm] AS t ON k.[TermCode] = t.[TermCode]
    INNER JOIN [compliance].[MeasureDefinition] AS md ON k.[MeasureCode] = md.[MeasureCode]
    WHERE k.[AcademicYear] = @ReportingPeriod;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'ROW_COUNT', 'RECONCILIATION', '=',
            (
                SELECT COUNT(md.[MeasureCode]) FROM [reference].[AcademicTerm] AS t CROSS JOIN [compliance].[MeasureDefinition] AS md
                WHERE t.[AcademicYear] = @ReportingPeriod
            ),
            (SELECT COUNT(*) FROM [reporting].[vw_LeadershipKPI] AS k WHERE k.[AcademicYear] = @ReportingPeriod),
            NULL
        ),
        (
            'FALL_CENSUS_HEADCOUNT', 'RECONCILIATION', '=',
            @FallIncluded,
            (
                SELECT ISNULL(SUM(k.[MeasureValue]), 0) FROM [reporting].[vw_LeadershipKPI] AS k
                WHERE k.[AcademicYear] = @ReportingPeriod AND k.[TermType] = 'FALL' AND k.[MeasureCode] = 'CENSUS_HEADCOUNT'
            ),
            CASE WHEN @FallIncluded IS NULL THEN N'The fall term has no census snapshot yet.' END
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
