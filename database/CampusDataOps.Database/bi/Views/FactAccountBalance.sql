-- Student account balances and aging buckets as of today. Grain: student.
CREATE VIEW [bi].[FactAccountBalance]
AS
SELECT
    sp.[StudentKey],
    a.[AsOfDate],
    a.[NetBalance],
    a.[CurrentAmount],
    a.[Days001To030],
    a.[Days031To060],
    a.[Days061To090],
    a.[Days091Plus],
    a.[CreditBalance]
FROM [reporting].[vw_StudentAccountAging] AS a
LEFT JOIN [security].[StudentPseudonym] AS sp ON a.[IdNumber] = sp.[IdNumber];
