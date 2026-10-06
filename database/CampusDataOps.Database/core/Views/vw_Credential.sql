-- Conformed credential awards with the program's CIP code and IPEDS award level.
-- ReportingYear is the July-June year containing the award date (IPEDS Completions period).
CREATE VIEW [core].[vw_Credential]
AS
SELECT
    c.[CredentialAwardedId],
    c.[IdNumber],
    c.[ProgramCode],
    c.[TermCode],
    c.[AwardedDate],
    p.[CipCode],
    p.[CredentialLevel],
    p.[IpedsAwardLevel],
    p.[RequiredCredits],
    CONCAT(y.[StartYear], '-', y.[StartYear] + 1) AS [ReportingYear]
FROM [staging].[CredentialAwarded] AS c
LEFT JOIN [reference].[AcademicProgram] AS p ON c.[ProgramCode] = p.[ProgramCode]
CROSS APPLY ( -- noqa: ST05
    SELECT YEAR(c.[AwardedDate]) - CASE WHEN MONTH(c.[AwardedDate]) < 7 THEN 1 ELSE 0 END AS [StartYear]
) AS y;
