-- Financial aid award facts. Grain: award (student, term and fund).
CREATE VIEW [bi].[FactAidAward]
AS
SELECT
    a.[AwardId],
    sp.[StudentKey],
    a.[AidYear],
    a.[TermCode],
    a.[FundCode],
    a.[FundSource],
    a.[FundType],
    a.[AwardStatus],
    a.[OfferedAmount],
    a.[AcceptedAmount],
    a.[DisbursedAmount]
FROM [core].[vw_AidAward] AS a
LEFT JOIN [security].[StudentPseudonym] AS sp ON a.[IdNumber] = sp.[IdNumber];
