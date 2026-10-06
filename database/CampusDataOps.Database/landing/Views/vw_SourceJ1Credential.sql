CREATE VIEW [landing].[vw_SourceJ1Credential]
AS
SELECT
    ca.[CredentialAwardedId],
    ca.[IdNumber],
    ca.[ProgramCode],
    ca.[TermCode],
    ca.[AwardedDate],
    ca.[UpdatedAtUtc] AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[J1Sim].[CredentialAwarded] AS ca;
