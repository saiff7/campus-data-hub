-- R2 Financial aid packaging report (docs/specifications/report-catalog.md).
-- Grain: one row per student, aid year and fund; term awards within the aid year are summed.
CREATE VIEW [reporting].[vw_FinancialAidPackaging]
AS
SELECT
    a.[IdNumber],
    a.[AidYear],
    a.[FundCode],
    a.[FundSource],
    a.[FundType],
    COUNT(*) AS [AwardCount],
    SUM(a.[OfferedAmount]) AS [OfferedAmount],
    SUM(a.[AcceptedAmount]) AS [AcceptedAmount],
    SUM(a.[DisbursedAmount]) AS [DisbursedAmount],
    SUM(CASE WHEN a.[AwardStatus] = 'CANCELLED' THEN a.[OfferedAmount] ELSE 0 END) AS [CancelledAmount],
    SUM(CASE WHEN a.[AwardStatus] = 'DECLINED' THEN a.[OfferedAmount] ELSE 0 END) AS [DeclinedAmount],
    SUM(a.[AcceptedAmount] - a.[DisbursedAmount]) AS [RemainingAmount]
FROM [core].[vw_AidAward] AS a
GROUP BY a.[IdNumber], a.[AidYear], a.[FundCode], a.[FundSource], a.[FundType];
