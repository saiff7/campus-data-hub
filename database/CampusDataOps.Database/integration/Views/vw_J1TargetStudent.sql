-- Target-side evidence for reconciliation: what J1-Sim actually holds for each receipt of the
-- import interface. This view is the only read of J1-Sim outside landing, so tests can fake it.
CREATE VIEW [integration].[vw_J1TargetStudent]
AS
SELECT
    r.[IdempotencyKey],
    r.[IdNumber],
    r.[ActionCode],
    r.[SourceApplicationId],
    CAST(CASE WHEN p.[IdNumber] IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS [PersonExists],
    s.[ProgramCode],
    s.[EntryTermCode],
    s.[StudentStatus]
FROM [$(SourceSystems)].[J1Sim].[IntegrationReceipt] AS r
LEFT JOIN [$(SourceSystems)].[J1Sim].[Person] AS p ON r.[IdNumber] = p.[IdNumber]
LEFT JOIN [$(SourceSystems)].[J1Sim].[Student] AS s ON r.[IdNumber] = s.[IdNumber];
