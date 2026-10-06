-- The IPEDS-aligned 12-month population (docs/specifications/ipeds-measure-mapping.md): one row
-- per student and academic year (1 July to 30 June) with at least one REGISTERED or WITHDRAWN
-- section in a term starting in that year. Attendance status and category come from the
-- student's first such term (project assumption); full-time uses the current census rule.
CREATE VIEW [compliance].[vw_TwelveMonthStudent]
AS
WITH [StudentTerm] AS (
    SELECT
        e.[IdNumber],
        t.[AcademicYear],
        t.[TermCode],
        t.[StartDate],
        SUM(e.[CreditHours]) AS [AttemptedCredits]
    FROM [core].[vw_Enrollment] AS e
    INNER JOIN [core].[vw_Term] AS t ON e.[TermCode] = t.[TermCode]
    WHERE e.[IsAttempted] = 1
    GROUP BY e.[IdNumber], t.[AcademicYear], t.[TermCode], t.[StartDate]
),

[Ranked] AS (
    SELECT
        st.[IdNumber],
        st.[AcademicYear],
        st.[TermCode],
        st.[AttemptedCredits],
        ROW_NUMBER() OVER (PARTITION BY st.[IdNumber], st.[AcademicYear] ORDER BY st.[StartDate]) AS [TermRank],
        SUM(st.[AttemptedCredits]) OVER (PARTITION BY st.[IdNumber], st.[AcademicYear]) AS [YearCredits]
    FROM [StudentTerm] AS st
)

SELECT
    r.[IdNumber],
    r.[AcademicYear],
    r.[TermCode] AS [FirstTermCode],
    CAST(r.[YearCredits] AS DECIMAL (7, 1)) AS [CreditHours],
    CASE WHEN r.[AttemptedCredits] >= crv.[FullTimeMinCredits] THEN 'FULL_TIME' ELSE 'PART_TIME' END AS [AttendanceStatus],
    CASE WHEN s.[EntryTermCode] = r.[TermCode] THEN 'ENTERING' ELSE 'CONTINUING' END AS [StudentCategory]
FROM [Ranked] AS r
CROSS JOIN [compliance].[CensusRuleVersion] AS crv
LEFT JOIN [core].[vw_Student] AS s ON r.[IdNumber] = s.[IdNumber]
WHERE r.[TermRank] = 1
  AND crv.[IsCurrent] = 1;
