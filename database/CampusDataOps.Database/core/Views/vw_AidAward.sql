-- Conformed financial aid awards with fund classification.
CREATE VIEW [core].[vw_AidAward]
AS
SELECT
    a.[AwardId],
    a.[IdNumber],
    a.[AidYear],
    a.[TermCode],
    a.[FundCode],
    f.[FundSource],
    f.[FundType],
    f.[IsPell],
    f.[IsFederalStudentLoan],
    a.[AwardStatus],
    a.[OfferedAmount],
    a.[AcceptedAmount],
    a.[DisbursedAmount]
FROM [staging].[FinancialAidAward] AS a
LEFT JOIN [reference].[AidFund] AS f ON a.[FundCode] = f.[FundCode];
