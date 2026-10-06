-- Conformed SIS students: one active program per student (simulator simplification).
CREATE VIEW [core].[vw_Student]
AS
SELECT
    p.[IdNumber],
    p.[StudentProgramCode] AS [ProgramCode],
    p.[StudentEntryTermCode] AS [EntryTermCode],
    p.[StudentStatus],
    p.[ResidencyCode],
    p.[MatriculationDate],
    p.[BirthDate]
FROM [staging].[Person] AS p
WHERE p.[HasStudentRecord] = 1;
