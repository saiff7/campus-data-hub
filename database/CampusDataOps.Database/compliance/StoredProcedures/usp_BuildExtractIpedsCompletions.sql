-- IPEDS-aligned Completions (educational simulation) for one academic year.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractIpedsCompletions]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, N'ReportingPeriod,Section,CipCode,AwardLevel,AwardCount');

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY c.[Section], c.[CipCode], c.[AwardLevel]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[ReportingPeriod])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[Section])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[CipCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[AwardLevel])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), c.[AwardCount]))
        ) AS [LineText]
    FROM [compliance].[vw_IPEDS_Completions] AS c
    WHERE c.[ReportingPeriod] = @ReportingPeriod;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'AWARDS_TOTAL', 'RECONCILIATION', '=',
            (SELECT COUNT(*) FROM [core].[vw_Credential] AS cr WHERE cr.[ReportingYear] = @ReportingPeriod),
            (
                SELECT ISNULL(SUM(c.[AwardCount]), 0)
                FROM [compliance].[vw_IPEDS_Completions] AS c
                WHERE c.[ReportingPeriod] = @ReportingPeriod AND c.[Section] = 'AWARDS'
            ),
            NULL
        ),
        (
            'COMPLETERS_AT_MOST_AWARDS', 'RULE', '<=',
            (
                SELECT ISNULL(SUM(c.[AwardCount]), 0)
                FROM [compliance].[vw_IPEDS_Completions] AS c
                WHERE c.[ReportingPeriod] = @ReportingPeriod AND c.[Section] = 'AWARDS'
            ),
            (
                SELECT ISNULL(SUM(c.[AwardCount]), 0)
                FROM [compliance].[vw_IPEDS_Completions] AS c
                WHERE c.[ReportingPeriod] = @ReportingPeriod AND c.[Section] = 'COMPLETERS_TOTAL'
            ),
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
