-- Nightly integration runs with their reconciliation counts. Grain: run.
CREATE VIEW [bi].[FactIntegrationRun]
AS
SELECT
    b.[BatchId],
    b.[BatchStatusCode],
    b.[StartedAtUtc],
    b.[EndedAtUtc],
    b.[RecoveryOfBatchId],
    r.[SourceEligible],
    r.[Created],
    r.[Matched],
    r.[Unchanged],
    r.[Rejected],
    r.[Pending],
    r.[IsBalanced],
    CAST(b.[StartedAtUtc] AS DATE) AS [RunDate],
    DATEDIFF(SECOND, b.[StartedAtUtc], b.[EndedAtUtc]) AS [DurationSeconds]
FROM [audit].[BatchRun] AS b
LEFT JOIN [integration].[ReconciliationResult] AS r ON b.[BatchId] = r.[BatchId]
WHERE b.[ProcessName] = 'NIGHTLY_INTEGRATION';
