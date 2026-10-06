-- R5 Applicant integration exception worklist, masked (docs/specifications/report-catalog.md).
-- Grain: one row per active exception. Applicant identity is reduced to initials, birth year and
-- a masked email; full values are available only through reporting.usp_GetExceptionDetail.
CREATE VIEW [reporting].[vw_ExceptionWorklist]
AS
SELECT
    w.[ExceptionId],
    w.[ExceptionReasonCode],
    w.[ReasonCategory],
    w.[Severity],
    w.[OwnerDepartment],
    w.[BlocksProcessing],
    w.[ExceptionStatusCode],
    w.[AssignedTo],
    w.[ApplicationId],
    w.[DetailCode],
    w.[CurrentDecisionType],
    w.[CandidateCount],
    w.[OccurrenceCount],
    w.[CreatedAtUtc],
    w.[AgeDays],
    w.[RemediationGuidance],
    a.[EntryTermCodeRaw],
    a.[ProgramChoice1Raw],
    nxt.[PermittedNextStatuses],
    CONCAT(LEFT(a.[FirstNameStd], 1), LEFT(a.[LastNameStd], 1)) AS [ApplicantInitials],
    YEAR(a.[BirthDate]) AS [BirthYear],
    CASE
        WHEN a.[EmailStd] IS NOT NULL
            THEN CONCAT(LEFT(a.[EmailStd], 1), '***', SUBSTRING(a.[EmailStd], CHARINDEX('@', a.[EmailStd]), 320))
        WHEN a.[EmailRaw] IS NOT NULL THEN '(invalid)'
    END AS [MaskedEmail]
FROM [integration].[vw_OpenExceptionWorklist] AS w
LEFT JOIN [core].[vw_Application] AS a ON w.[ApplicationId] = a.[ApplicationId]
OUTER APPLY (
    SELECT STRING_AGG(CONVERT(VARCHAR (MAX), tr.[ToStatusCode]), ',') WITHIN GROUP (ORDER BY tr.[ToStatusCode]) AS [PermittedNextStatuses]
    FROM [reference].[ExceptionStatusTransition] AS tr
    WHERE tr.[FromStatusCode] = w.[ExceptionStatusCode]
) AS nxt;
