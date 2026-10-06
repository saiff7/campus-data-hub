-- Weekly data-quality scorecard from the latest validation run.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractDqScorecard]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, CONCAT(
        N'ValidationRunId,BatchId,RuleCode,EntityName,Severity,OwnerDepartment,',
        N'RecordsEvaluated,RecordsFailed,PassRate'
    ));

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY d.[RuleCode]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), d.[ValidationRunId])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), d.[BatchId])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), d.[RuleCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), d.[EntityName])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), d.[Severity])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), d.[OwnerDepartment])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), d.[RecordsEvaluated])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), d.[RecordsFailed])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), d.[PassRate]))
        ) AS [LineText]
    FROM [dq].[vw_DataQualityScorecard] AS d;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'FAILURES_TOTAL', 'RECONCILIATION', '=',
            (
                SELECT vr.[FailuresFound] FROM [dq].[ValidationRun] AS vr
                WHERE vr.[ValidationRunId] = (SELECT MAX(latest.[ValidationRunId]) FROM [dq].[ValidationRun] AS latest)
            ),
            (SELECT ISNULL(SUM(d.[RecordsFailed]), 0) FROM [dq].[vw_DataQualityScorecard] AS d),
            NULL
        ),
        (
            'RULES_EVALUATED', 'RECONCILIATION', '=',
            (
                SELECT vr.[RulesEvaluated] FROM [dq].[ValidationRun] AS vr
                WHERE vr.[ValidationRunId] = (SELECT MAX(latest.[ValidationRunId]) FROM [dq].[ValidationRun] AS latest)
            ),
            (SELECT COUNT(d.[RuleCode]) FROM [dq].[vw_DataQualityScorecard] AS d),
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
