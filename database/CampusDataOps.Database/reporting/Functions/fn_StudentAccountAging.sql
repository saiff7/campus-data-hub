-- R3 Student account aging as of a date (docs/specifications/report-catalog.md).
-- Grain: one row per student with a transaction posted on or before @AsOfDate.
-- Credits (negative amounts) pay debits oldest effective due date first, then by transaction id
-- (first-in-first-out: the source does not record which charge a payment paid). Each debit's
-- unpaid remainder is aged into reference.AgingBucket by days past due on @AsOfDate.
-- Invariant: CURRENT + D001_030 + D031_060 + D061_090 + D091_PLUS - CreditBalance = NetBalance.
CREATE FUNCTION [reporting].[fn_StudentAccountAging] (@AsOfDate DATE)
RETURNS TABLE
AS
RETURN
WITH [Posted] AS (
    SELECT t.[TransactionId], t.[IdNumber], t.[TransactionType], t.[Amount], t.[PostedDate], t.[EffectiveDueDate]
    FROM [core].[vw_AccountTransaction] AS t
    WHERE t.[PostedDate] <= @AsOfDate
),

[StudentTotal] AS (
    SELECT
        p.[IdNumber],
        SUM(p.[Amount]) AS [NetBalance],
        SUM(CASE WHEN p.[Amount] > 0 THEN p.[Amount] ELSE 0 END) AS [DebitTotal],
        SUM(CASE WHEN p.[Amount] < 0 THEN -p.[Amount] ELSE 0 END) AS [CreditTotal],
        COUNT(*) AS [TransactionCount]
    FROM [Posted] AS p
    GROUP BY p.[IdNumber]
),

[LastPayment] AS (
    SELECT p.[IdNumber], MAX(p.[PostedDate]) AS [LastPaymentDate]
    FROM [Posted] AS p
    WHERE p.[TransactionType] = 'PAYMENT'
    GROUP BY p.[IdNumber]
),

[Debit] AS (
    SELECT
        p.[IdNumber],
        p.[Amount],
        DATEDIFF(DAY, p.[EffectiveDueDate], @AsOfDate) AS [DaysPastDue],
        SUM(p.[Amount]) OVER (
            PARTITION BY p.[IdNumber] ORDER BY p.[EffectiveDueDate], p.[TransactionId] ROWS UNBOUNDED PRECEDING
        ) AS [CumulativeDebit]
    FROM [Posted] AS p
    WHERE p.[Amount] > 0
),

[Outstanding] AS (
    SELECT
        d.[IdNumber],
        d.[DaysPastDue],
        d.[Amount] - CASE
            WHEN st.[CreditTotal] >= d.[CumulativeDebit] THEN d.[Amount]
            WHEN st.[CreditTotal] <= d.[CumulativeDebit] - d.[Amount] THEN 0
            ELSE st.[CreditTotal] - (d.[CumulativeDebit] - d.[Amount])
        END AS [UnpaidAmount]
    FROM [Debit] AS d
    INNER JOIN [StudentTotal] AS st ON d.[IdNumber] = st.[IdNumber]
),

[Aged] AS (
    SELECT
        o.[IdNumber],
        SUM(CASE WHEN b.[BucketCode] = 'CURRENT' THEN o.[UnpaidAmount] ELSE 0 END) AS [CurrentAmount],
        SUM(CASE WHEN b.[BucketCode] = 'D001_030' THEN o.[UnpaidAmount] ELSE 0 END) AS [Days001To030],
        SUM(CASE WHEN b.[BucketCode] = 'D031_060' THEN o.[UnpaidAmount] ELSE 0 END) AS [Days031To060],
        SUM(CASE WHEN b.[BucketCode] = 'D061_090' THEN o.[UnpaidAmount] ELSE 0 END) AS [Days061To090],
        SUM(CASE WHEN b.[BucketCode] = 'D091_PLUS' THEN o.[UnpaidAmount] ELSE 0 END) AS [Days091Plus]
    FROM [Outstanding] AS o
    INNER JOIN [reference].[AgingBucket] AS b
        ON (b.[MinDaysPastDue] IS NULL OR o.[DaysPastDue] >= b.[MinDaysPastDue])
       AND (b.[MaxDaysPastDue] IS NULL OR o.[DaysPastDue] <= b.[MaxDaysPastDue])
    GROUP BY o.[IdNumber]
)

SELECT
    st.[IdNumber],
    st.[NetBalance],
    st.[TransactionCount],
    lp.[LastPaymentDate],
    @AsOfDate AS [AsOfDate],
    ISNULL(a.[CurrentAmount], 0) AS [CurrentAmount],
    ISNULL(a.[Days001To030], 0) AS [Days001To030],
    ISNULL(a.[Days031To060], 0) AS [Days031To060],
    ISNULL(a.[Days061To090], 0) AS [Days061To090],
    ISNULL(a.[Days091Plus], 0) AS [Days091Plus],
    CASE WHEN st.[CreditTotal] > st.[DebitTotal] THEN st.[CreditTotal] - st.[DebitTotal] ELSE 0 END AS [CreditBalance]
FROM [StudentTotal] AS st
LEFT JOIN [Aged] AS a ON st.[IdNumber] = a.[IdNumber]
LEFT JOIN [LastPayment] AS lp ON st.[IdNumber] = lp.[IdNumber];
