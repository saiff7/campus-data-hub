-- Extract boundary for J1-Sim people with their student record, if any.
CREATE VIEW [landing].[vw_SourceJ1Person]
AS
SELECT
    p.[IdNumber],
    p.[FirstName],
    p.[MiddleName],
    p.[LastName],
    p.[BirthDate],
    p.[Email],
    p.[Phone],
    p.[AddressLine1],
    p.[City],
    p.[StateCode],
    p.[PostalCode],
    s.[ProgramCode] AS [StudentProgramCode],
    s.[EntryTermCode] AS [StudentEntryTermCode],
    s.[StudentStatus],
    s.[ResidencyCode],
    s.[MatriculationDate],
    GREATEST(p.[UpdatedAtUtc], s.[UpdatedAtUtc]) AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[J1Sim].[Person] AS p
LEFT JOIN [$(SourceSystems)].[J1Sim].[Student] AS s ON p.[IdNumber] = s.[IdNumber];
