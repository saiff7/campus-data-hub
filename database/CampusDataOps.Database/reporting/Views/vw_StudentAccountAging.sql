-- R3 as of today (UTC). Use reporting.usp_ReportAccountAging for another date.
CREATE VIEW [reporting].[vw_StudentAccountAging]
AS
SELECT
    a.[IdNumber], a.[AsOfDate], a.[NetBalance], a.[TransactionCount], a.[LastPaymentDate], a.[CurrentAmount], a.[Days001To030],
    a.[Days031To060], a.[Days061To090], a.[Days091Plus], a.[CreditBalance]
FROM [reporting].[fn_StudentAccountAging](CAST(SYSUTCDATETIME() AS DATE)) AS a;
