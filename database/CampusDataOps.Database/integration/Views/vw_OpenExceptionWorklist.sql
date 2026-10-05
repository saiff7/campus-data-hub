-- Operational worklist of active exceptions. It shows identifiers, codes and ages only; names,
-- birth dates and contact values stay in staging for authorized drill-through (Part 3 adds
-- masked views and role grants).
CREATE VIEW [integration].[vw_OpenExceptionWorklist]
AS
SELECT
    e.[ExceptionId],
    e.[ExceptionReasonCode],
    r.[Category] AS [ReasonCategory],
    e.[Severity],
    r.[OwnerDepartment],
    r.[BlocksProcessing],
    e.[ExceptionStatusCode],
    e.[AssignedTo],
    e.[ApplicationId],
    a.[SlatePersonId],
    e.[SubjectBatchId],
    e.[DetailCode],
    d.[DecisionTypeCode] AS [CurrentDecisionType],
    d.[CandidateCount],
    e.[OccurrenceCount],
    e.[FirstSeenBatchId],
    e.[LastSeenBatchId],
    e.[CreatedAtUtc],
    r.[RemediationGuidance],
    DATEDIFF(DAY, e.[CreatedAtUtc], SYSUTCDATETIME()) AS [AgeDays]
FROM [integration].[IntegrationException] AS e
INNER JOIN [reference].[ExceptionReason] AS r ON e.[ExceptionReasonCode] = r.[ExceptionReasonCode]
INNER JOIN [reference].[ExceptionStatus] AS s ON e.[ExceptionStatusCode] = s.[ExceptionStatusCode]
LEFT JOIN [staging].[Applicant] AS a ON e.[ApplicationId] = a.[ApplicationId]
LEFT JOIN [integration].[MatchDecision] AS d
    ON e.[ApplicationId] = d.[ApplicationId]
   AND d.[IsCurrent] = 1
WHERE s.[IsActiveState] = 1;
