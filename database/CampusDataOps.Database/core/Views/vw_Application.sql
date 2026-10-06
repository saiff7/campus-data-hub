-- Conformed Slate-Sim applications. FunnelTermCode is the raw entry term when it names a
-- governed term (open or closed), so funnel counts do not depend on admission validation.
CREATE VIEW [core].[vw_Application]
AS
SELECT
    a.[ApplicationId],
    a.[SlatePersonId],
    a.[ApplicationStatus],
    a.[StudentType],
    a.[IsEligible],
    t.[TermCode] AS [FunnelTermCode],
    a.[EntryTermCode],
    a.[EntryTermCodeRaw],
    a.[ProgramChoice1Raw],
    a.[J1ProgramCode],
    a.[FirstNameRaw],
    a.[FirstNameStd],
    a.[LastNameRaw],
    a.[LastNameStd],
    a.[BirthDate],
    a.[EmailRaw],
    a.[EmailStd],
    a.[PhoneRaw],
    a.[PhoneStd],
    a.[PostalCode5],
    a.[ResidencyCode],
    a.[SisIdClaim]
FROM [staging].[Applicant] AS a
LEFT JOIN [reference].[AcademicTerm] AS t ON a.[EntryTermCodeRaw] = t.[TermCode];
