-- Data-quality rule results for every validation run (trend). Grain: validation run and rule.
CREATE VIEW [bi].[FactDataQualityResult]
AS
SELECT
    x.[ValidationRunId],
    v.[BatchId],
    x.[RuleCode],
    x.[RecordsEvaluated],
    x.[RecordsFailed],
    CAST(v.[StartedAtUtc] AS DATE) AS [RunDate]
FROM [dq].[RuleExecution] AS x
INNER JOIN [dq].[ValidationRun] AS v ON x.[ValidationRunId] = v.[ValidationRunId];
