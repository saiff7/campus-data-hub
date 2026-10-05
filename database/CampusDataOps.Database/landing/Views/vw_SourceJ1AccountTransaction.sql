CREATE VIEW [landing].[vw_SourceJ1AccountTransaction]
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
    t.[UpdatedAtUtc] AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[J1Sim].[StudentAccountTransaction] AS t;
