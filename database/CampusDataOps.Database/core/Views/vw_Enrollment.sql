-- Conformed course enrollments with census and grade flags (docs/specifications/report-catalog.md R1, R4).
-- A section counts at census when it was registered by the end of the census date and was
-- still REGISTERED then. The source keeps only the latest status change, so a section changed
-- after the census date is treated as REGISTERED at census.
CREATE VIEW [core].[vw_Enrollment]
AS
SELECT
    e.[EnrollmentId],
    e.[IdNumber],
    e.[CourseSectionId],
    e.[TermCode],
    e.[SubjectCode],
    e.[CourseNumber],
    e.[SectionNumber],
    e.[CreditHours],
    e.[RegistrationStatus],
    e.[RegisteredAtUtc],
    e.[StatusChangedAtUtc],
    e.[GradeCode],
    e.[GradePoints],
    CAST(CASE WHEN e.[RegistrationStatus] = 'DROPPED' THEN 0 ELSE 1 END AS BIT) AS [IsAttempted],
    CAST(CASE
        WHEN e.[RegisteredAtUtc] < c.[CensusEndUtc]
            AND (e.[RegistrationStatus] = 'REGISTERED' OR e.[StatusChangedAtUtc] >= c.[CensusEndUtc]) THEN 1
        ELSE 0
    END AS BIT) AS [IsCountedAtCensus],
    CAST(CASE WHEN e.[RegisteredAtUtc] < c.[CensusEndUtc] THEN 1 ELSE 0 END AS BIT) AS [IsRegisteredByCensus]
FROM [staging].[Enrollment] AS e
LEFT JOIN [reference].[AcademicTerm] AS t ON e.[TermCode] = t.[TermCode]
CROSS APPLY ( -- noqa: ST05
    SELECT CAST(DATEADD(DAY, 1, t.[CensusDate]) AS DATETIME2 (3)) AS [CensusEndUtc]
) AS c;
