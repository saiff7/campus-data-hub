CREATE VIEW [landing].[vw_SourceJ1FinancialAid]
AS
SELECT
    fa.[AwardId],
    fa.[IdNumber],
    fa.[AidYear],
    fa.[TermCode],
    fa.[FundCode],
    fa.[AwardStatus],
    fa.[OfferedAmount],
    fa.[AcceptedAmount],
    fa.[DisbursedAmount],
    fa.[UpdatedAtUtc] AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[J1Sim].[FinancialAidAward] AS fa;
