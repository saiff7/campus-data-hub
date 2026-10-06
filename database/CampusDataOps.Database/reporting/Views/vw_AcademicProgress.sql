-- R4 Academic progress (docs/specifications/report-catalog.md).
-- Grain: one row per student per term with at least one section that was not dropped.
-- Earned: graded D or better (grade points >= 1.00). GPA credits: grades that carry points
-- (W and I do not). Cumulative values run over this and every earlier term by term start date.
CREATE VIEW [reporting].[vw_AcademicProgress]
AS
WITH [TermTotal] AS (
    SELECT
        e.[IdNumber],
        e.[TermCode],
        t.[StartDate],
        t.[EndDate],
        SUM(CASE WHEN e.[IsAttempted] = 1 THEN e.[CreditHours] ELSE 0 END) AS [AttemptedCredits],
        SUM(CASE WHEN e.[IsAttempted] = 1 AND e.[GradePoints] >= 1.00 THEN e.[CreditHours] ELSE 0 END) AS [EarnedCredits],
        SUM(CASE WHEN e.[IsAttempted] = 1 AND e.[GradePoints] IS NOT NULL THEN e.[CreditHours] ELSE 0 END) AS [GpaCredits],
        SUM(
            CASE WHEN e.[IsAttempted] = 1 AND e.[GradePoints] IS NOT NULL THEN e.[GradePoints] * e.[CreditHours] ELSE 0 END
        ) AS [QualityPoints],
        SUM(CASE WHEN e.[RegistrationStatus] = 'REGISTERED' AND e.[GradeCode] IS NULL THEN 1 ELSE 0 END) AS [PendingSections],
        SUM(CASE WHEN e.[IsAttempted] = 1 THEN 1 ELSE 0 END) AS [AttemptedSections]
    FROM [core].[vw_Enrollment] AS e
    INNER JOIN [reference].[AcademicTerm] AS t ON e.[TermCode] = t.[TermCode]
    GROUP BY e.[IdNumber], e.[TermCode], t.[StartDate], t.[EndDate]
),

[Cumulative] AS (
    SELECT
        tt.[IdNumber],
        tt.[TermCode],
        tt.[StartDate],
        tt.[EndDate],
        tt.[AttemptedCredits],
        tt.[EarnedCredits],
        tt.[GpaCredits],
        tt.[QualityPoints],
        tt.[PendingSections],
        SUM(tt.[AttemptedCredits]) OVER (PARTITION BY tt.[IdNumber] ORDER BY tt.[StartDate] ROWS UNBOUNDED PRECEDING)
            AS [CumulativeAttemptedCredits],
        SUM(tt.[EarnedCredits]) OVER (PARTITION BY tt.[IdNumber] ORDER BY tt.[StartDate] ROWS UNBOUNDED PRECEDING)
            AS [CumulativeEarnedCredits],
        SUM(tt.[GpaCredits]) OVER (PARTITION BY tt.[IdNumber] ORDER BY tt.[StartDate] ROWS UNBOUNDED PRECEDING)
            AS [CumulativeGpaCredits],
        SUM(tt.[QualityPoints]) OVER (PARTITION BY tt.[IdNumber] ORDER BY tt.[StartDate] ROWS UNBOUNDED PRECEDING)
            AS [CumulativeQualityPoints]
    FROM [TermTotal] AS tt
    WHERE tt.[AttemptedSections] > 0
),

[Gpa] AS (
    SELECT
        c.[IdNumber],
        c.[TermCode],
        c.[StartDate],
        c.[EndDate],
        c.[AttemptedCredits],
        c.[EarnedCredits],
        c.[GpaCredits],
        c.[QualityPoints],
        c.[PendingSections],
        c.[CumulativeAttemptedCredits],
        c.[CumulativeEarnedCredits],
        c.[CumulativeGpaCredits],
        c.[CumulativeQualityPoints],
        CAST(CASE WHEN c.[GpaCredits] > 0 THEN ROUND(c.[QualityPoints] / c.[GpaCredits], 2) END AS DECIMAL (3, 2)) AS [TermGpa],
        CAST(CASE
            WHEN c.[CumulativeGpaCredits] > 0 THEN ROUND(c.[CumulativeQualityPoints] / c.[CumulativeGpaCredits], 2)
        END AS DECIMAL (3, 2)) AS [CumulativeGpa]
    FROM [Cumulative] AS c
)

SELECT
    g.[IdNumber],
    g.[TermCode],
    s.[ProgramCode],
    g.[TermGpa],
    g.[CumulativeGpa],
    p.[RequiredCredits],
    CAST(g.[AttemptedCredits] AS DECIMAL (5, 1)) AS [AttemptedCredits],
    CAST(g.[EarnedCredits] AS DECIMAL (5, 1)) AS [EarnedCredits],
    CAST(g.[GpaCredits] AS DECIMAL (5, 1)) AS [GpaCredits],
    CAST(g.[QualityPoints] AS DECIMAL (7, 2)) AS [QualityPoints],
    CAST(g.[CumulativeAttemptedCredits] AS DECIMAL (6, 1)) AS [CumulativeAttemptedCredits],
    CAST(g.[CumulativeEarnedCredits] AS DECIMAL (6, 1)) AS [CumulativeEarnedCredits],
    CAST(g.[CumulativeGpaCredits] AS DECIMAL (6, 1)) AS [CumulativeGpaCredits],
    CAST(CASE WHEN g.[PendingSections] > 0 THEN 1 ELSE 0 END AS BIT) AS [GradesPending],
    CAST(CASE WHEN g.[CumulativeEarnedCredits] >= p.[RequiredCredits] THEN 1 ELSE 0 END AS BIT) AS [IsCompletionEligible],
    CAST(CASE WHEN cr.[CredentialAwardedId] IS NULL THEN 0 ELSE 1 END AS BIT) AS [HasCredential],
    CASE WHEN g.[CumulativeGpa] IS NULL THEN 'NOT_EVALUATED' ELSE st.[StandingCode] END AS [AcademicStanding]
FROM [Gpa] AS g
LEFT JOIN [core].[vw_Student] AS s ON g.[IdNumber] = s.[IdNumber]
LEFT JOIN [reference].[AcademicProgram] AS p ON s.[ProgramCode] = p.[ProgramCode]
OUTER APPLY (
    SELECT TOP (1) r.[StandingCode]
    FROM [reference].[AcademicStandingRule] AS r
    WHERE g.[CumulativeGpa] >= r.[MinCumulativeGpa]
      AND (r.[MaxCumulativeGpaExclusive] IS NULL OR g.[CumulativeGpa] < r.[MaxCumulativeGpaExclusive])
    ORDER BY r.[MinCumulativeGpa] DESC
) AS st
OUTER APPLY (
    SELECT TOP (1) c.[CredentialAwardedId]
    FROM [core].[vw_Credential] AS c
    INNER JOIN [reference].[AcademicTerm] AS ct ON c.[TermCode] = ct.[TermCode]
    WHERE c.[IdNumber] = g.[IdNumber]
      AND c.[ProgramCode] = s.[ProgramCode]
      AND ct.[StartDate] <= g.[StartDate]
    ORDER BY c.[AwardedDate]
) AS cr;
