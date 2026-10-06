-- Course outcome counts. Grain: term, subject and the student's program (aggregate).
CREATE VIEW [bi].[FactCourseOutcome]
AS
SELECT
    e.[TermCode],
    e.[SubjectCode],
    s.[ProgramCode],
    SUM(CASE WHEN e.[IsAttempted] = 1 THEN 1 ELSE 0 END) AS [AttemptedSections],
    SUM(CASE WHEN e.[IsAttempted] = 1 AND e.[GradeCode] IS NOT NULL THEN 1 ELSE 0 END) AS [GradedSections],
    SUM(CASE WHEN e.[IsAttempted] = 1 AND e.[GradePoints] >= 2.00 THEN 1 ELSE 0 END) AS [SuccessfulSections],
    SUM(CASE WHEN e.[IsAttempted] = 1 THEN e.[CreditHours] ELSE 0 END) AS [AttemptedCredits]
FROM [core].[vw_Enrollment] AS e
LEFT JOIN [core].[vw_Student] AS s ON e.[IdNumber] = s.[IdNumber]
GROUP BY e.[TermCode], e.[SubjectCode], s.[ProgramCode];
