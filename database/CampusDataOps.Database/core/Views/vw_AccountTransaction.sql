-- Conformed student account transactions. Positive amounts are debits; a debit without a due
-- date (refunds, adjustments) is due when posted (docs/specifications/report-catalog.md R3).
CREATE VIEW [core].[vw_AccountTransaction]
AS
SELECT
    t.[TransactionId],
    t.[IdNumber],
    t.[TermCode],
    t.[TransactionType],
    t.[DetailCode],
    t.[Amount],
    t.[PostedDate],
    t.[DueDate],
    COALESCE(t.[DueDate], t.[PostedDate]) AS [EffectiveDueDate]
FROM [staging].[AccountTransaction] AS t;
