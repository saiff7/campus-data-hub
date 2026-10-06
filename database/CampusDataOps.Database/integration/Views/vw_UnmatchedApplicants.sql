-- Eligible applications not yet written to J1-Sim, with why they are waiting: no decision
-- yet, a blocked identity decision, or a blocking exception.
CREATE VIEW [integration].[vw_UnmatchedApplicants]
AS
SELECT
    a.[ApplicationId],
    a.[SlatePersonId],
    a.[EntryTermCode],
    a.[J1ProgramCode],
    d.[DecisionTypeCode] AS [CurrentDecisionType],
    d.[RuleCode],
    d.[CandidateCount],
    d.[ConflictCode],
    blocking.[BlockingReasonCount],
    q.[QueueStatusCode]
FROM [staging].[Applicant] AS a
LEFT JOIN [integration].[MatchDecision] AS d
    ON a.[ApplicationId] = d.[ApplicationId]
   AND d.[IsCurrent] = 1
LEFT JOIN [integration].[OutboundStudentQueue] AS q
    ON a.[ApplicationId] = q.[ApplicationId]
   AND q.[QueueStatusCode] <> 'CANCELLED'
OUTER APPLY (
    SELECT COUNT(*) AS [BlockingReasonCount]
    FROM [integration].[vw_ApplicationBlock] AS b
    WHERE b.[ApplicationId] = a.[ApplicationId]
) AS blocking
WHERE a.[IsEligible] = 1
  AND NOT EXISTS (SELECT 1 FROM [integration].[vw_IntegratedApplication] AS ia WHERE ia.[ApplicationId] = a.[ApplicationId]);
