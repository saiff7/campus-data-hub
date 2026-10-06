-- Extract boundary for J1-Sim enrollments with their section and final grade.
CREATE VIEW [landing].[vw_SourceJ1Enrollment]
AS
SELECT
    e.[EnrollmentId],
    e.[IdNumber],
    e.[CourseSectionId],
    cs.[TermCode],
    cs.[SubjectCode],
    cs.[CourseNumber],
    cs.[SectionNumber],
    cs.[CreditHours],
    e.[RegistrationStatus],
    e.[RegisteredAtUtc],
    e.[StatusChangedAtUtc],
    fg.[GradeCode],
    fg.[GradePoints],
    fg.[PostedAtUtc] AS [GradePostedAtUtc],
    GREATEST(e.[UpdatedAtUtc], cs.[UpdatedAtUtc], fg.[UpdatedAtUtc]) AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[J1Sim].[Enrollment] AS e
INNER JOIN [$(SourceSystems)].[J1Sim].[CourseSection] AS cs ON e.[CourseSectionId] = cs.[CourseSectionId]
LEFT JOIN [$(SourceSystems)].[J1Sim].[FinalGrade] AS fg ON e.[EnrollmentId] = fg.[EnrollmentId];
