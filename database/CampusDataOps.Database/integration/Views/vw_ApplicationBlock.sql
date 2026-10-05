-- The single definition of "this application is blocked", used by matching, queueing and
-- reconciliation so they cannot disagree. A blocking exception blocks while it is OPEN,
-- ASSIGNED or AWAITING_SOURCE_CORRECTION; RESOLVED and RETRY_READY no longer block. A CLOSED
-- blocking exception keeps blocking while the application's staged version is the one the
-- analyst closed it for (system closures clear SourceHash, so they never block).
CREATE VIEW [integration].[vw_ApplicationBlock]
AS
SELECT
    e.[ApplicationId],
    e.[ExceptionId],
    e.[ExceptionReasonCode],
    r.[Category] AS [ReasonCategory],
    e.[Severity],
    e.[ExceptionStatusCode]
FROM [integration].[IntegrationException] AS e
INNER JOIN [reference].[ExceptionReason] AS r
    ON e.[ExceptionReasonCode] = r.[ExceptionReasonCode]
   AND r.[BlocksProcessing] = 1
INNER JOIN [staging].[Applicant] AS a ON e.[ApplicationId] = a.[ApplicationId]
WHERE e.[ExceptionStatusCode] = 'OPEN'
   OR e.[ExceptionStatusCode] = 'ASSIGNED'
   OR e.[ExceptionStatusCode] = 'AWAITING_SOURCE_CORRECTION'
   OR (e.[ExceptionStatusCode] = 'CLOSED' AND e.[SourceHash] = a.[SourceHash]);
