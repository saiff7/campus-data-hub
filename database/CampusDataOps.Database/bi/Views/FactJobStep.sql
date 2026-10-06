-- Pipeline step executions for the Job Health page. Grain: step attempt.
CREATE VIEW [bi].[FactJobStep]
AS
SELECT
    s.[BatchStepId],
    s.[BatchId],
    b.[ProcessName],
    s.[StepName],
    s.[StepOrder],
    s.[AttemptNumber],
    s.[BatchStepStatusCode],
    s.[StartedAtUtc],
    s.[EndedAtUtc],
    s.[RowsAffected],
    DATEDIFF(SECOND, s.[StartedAtUtc], s.[EndedAtUtc]) AS [DurationSeconds]
FROM [audit].[BatchStep] AS s
INNER JOIN [audit].[BatchRun] AS b ON s.[BatchId] = b.[BatchId];
