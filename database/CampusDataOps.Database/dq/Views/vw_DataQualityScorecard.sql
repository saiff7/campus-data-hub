-- Pass rate per rule for the most recent validation run.
CREATE VIEW [dq].[vw_DataQualityScorecard]
AS
SELECT
    x.[ValidationRunId],
    vr.[BatchId],
    x.[RuleCode],
    r.[EntityName],
    r.[Severity],
    r.[OwnerDepartment],
    x.[RecordsEvaluated],
    x.[RecordsFailed],
    CAST(CASE
        WHEN x.[RecordsEvaluated] = 0 THEN 1.0
        ELSE 1.0 - (CAST(x.[RecordsFailed] AS DECIMAL (18, 6)) / x.[RecordsEvaluated])
    END AS DECIMAL (9, 6)) AS [PassRate]
FROM [dq].[RuleExecution] AS x
INNER JOIN [dq].[Rule] AS r ON x.[RuleCode] = r.[RuleCode]
INNER JOIN [dq].[ValidationRun] AS vr ON x.[ValidationRunId] = vr.[ValidationRunId]
WHERE x.[ValidationRunId] = (SELECT MAX(latest.[ValidationRunId]) FROM [dq].[ValidationRun] AS latest);
