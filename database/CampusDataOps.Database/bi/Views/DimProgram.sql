-- Power BI program dimension with academic division (the program's department).
CREATE VIEW [bi].[DimProgram]
AS
SELECT
    p.[ProgramCode],
    p.[ProgramName],
    p.[CredentialLevel],
    p.[CipCode],
    p.[RequiredCredits],
    p.[IpedsAwardLevel],
    p.[DivisionCode],
    p.[DivisionName],
    p.[IsActive]
FROM [core].[vw_Program] AS p;
