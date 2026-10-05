-- Extract boundary for Slate-Sim people: one row per person with the primary email, primary
-- phone, primary address and SIS ID claim. SourceUpdatedAtUtc is the latest change across all
-- of those rows, so a corrected email alone makes the person eligible for the next load.
CREATE VIEW [landing].[vw_SourceSlateApplicant]
AS
SELECT
    p.[PersonId],
    p.[FirstName],
    p.[MiddleName],
    p.[LastName],
    p.[PreferredName],
    p.[BirthDate],
    email.[ContactValue] AS [Email],
    phone.[ContactValue] AS [Phone],
    addr.[Line1] AS [AddressLine1],
    addr.[Line2] AS [AddressLine2],
    addr.[City],
    addr.[StateCode],
    addr.[PostalCode],
    addr.[CountryCode],
    sis.[IdentifierValue] AS [SisIdClaim],
    GREATEST(p.[UpdatedAtUtc], email.[UpdatedAtUtc], phone.[UpdatedAtUtc], addr.[UpdatedAtUtc], sis.[UpdatedAtUtc])
        AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[SlateSim].[Person] AS p
LEFT JOIN [$(SourceSystems)].[SlateSim].[ContactPoint] AS email
    ON p.[PersonId] = email.[PersonId]
   AND email.[ContactType] = 'EMAIL'
   AND email.[IsPrimary] = 1
LEFT JOIN [$(SourceSystems)].[SlateSim].[ContactPoint] AS phone
    ON p.[PersonId] = phone.[PersonId]
   AND phone.[ContactType] = 'PHONE'
   AND phone.[IsPrimary] = 1
LEFT JOIN [$(SourceSystems)].[SlateSim].[Address] AS addr
    ON p.[PersonId] = addr.[PersonId]
   AND addr.[IsPrimary] = 1
LEFT JOIN [$(SourceSystems)].[SlateSim].[ExternalIdentifier] AS sis
    ON p.[PersonId] = sis.[PersonId]
   AND sis.[IdentifierType] = 'SIS_ID';
