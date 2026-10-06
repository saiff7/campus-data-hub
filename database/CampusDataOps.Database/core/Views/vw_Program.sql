-- Conformed SIS programs with their academic division.
CREATE VIEW [core].[vw_Program]
AS
SELECT
    p.[ProgramCode],
    p.[ProgramName],
    p.[CredentialLevel],
    p.[CipCode],
    p.[RequiredCredits],
    p.[IpedsAwardLevel],
    p.[DivisionCode],
    d.[DivisionName],
    p.[IsActive]
FROM [reference].[AcademicProgram] AS p
INNER JOIN [reference].[AcademicDivision] AS d ON p.[DivisionCode] = d.[DivisionCode];
