-- Failures from the most recent validation run, with rule ownership and remediation, the
-- first run in which the same rule failed for the same record, and the owner's current
-- disposition, if any (Part 3). A disposition annotates a failure; it never hides it.
CREATE VIEW [dq].[vw_CurrentDataQualityIssues]
AS
SELECT
    rr.[RuleCode],
    r.[Description] AS [RuleDescription],
    r.[EntityName],
    r.[Severity],
    r.[OwnerDepartment],
    rr.[RecordKey],
    rr.[DetailCode],
    rr.[ValidationRunId],
    vr.[BatchId],
    firstseen.[FirstValidationRunId],
    r.[RemediationGuidance],
    d.[DispositionCode],
    d.[ReviewBy] AS [DispositionReviewBy]
FROM [dq].[RuleResult] AS rr
INNER JOIN [dq].[Rule] AS r ON rr.[RuleCode] = r.[RuleCode]
INNER JOIN [dq].[ValidationRun] AS vr ON rr.[ValidationRunId] = vr.[ValidationRunId]
CROSS APPLY (
    SELECT MIN(earlier.[ValidationRunId]) AS [FirstValidationRunId]
    FROM [dq].[RuleResult] AS earlier
    WHERE earlier.[RuleCode] = rr.[RuleCode]
      AND earlier.[RecordKey] = rr.[RecordKey]
) AS firstseen
LEFT JOIN [dq].[IssueDisposition] AS d
    ON rr.[RuleCode] = d.[RuleCode]
   AND rr.[RecordKey] = d.[RecordKey]
   AND d.[IsCurrent] = 1
WHERE rr.[ValidationRunId] = (SELECT MAX(latest.[ValidationRunId]) FROM [dq].[ValidationRun] AS latest);
