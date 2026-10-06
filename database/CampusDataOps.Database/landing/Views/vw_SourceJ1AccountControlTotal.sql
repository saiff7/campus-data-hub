-- The source's own count and sum of account transactions per student and term. J1-Sim stores
-- no balance, so these totals, captured at load time, are what staged detail reconciles to.
CREATE VIEW [landing].[vw_SourceJ1AccountControlTotal]
AS
SELECT
    t.[IdNumber],
    t.[TermCode],
    COUNT_BIG(*) AS [TransactionCount],
    SUM(t.[Amount]) AS [AmountTotal],
    MAX(t.[UpdatedAtUtc]) AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[J1Sim].[StudentAccountTransaction] AS t
GROUP BY t.[IdNumber], t.[TermCode];
