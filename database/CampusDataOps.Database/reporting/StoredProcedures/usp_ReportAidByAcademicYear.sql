-- R2 for one aid year (YYYY-YYYY).
CREATE PROCEDURE [reporting].[usp_ReportAidByAcademicYear]
    @AidYear CHAR (9)
AS
BEGIN
    SET NOCOUNT ON;

    IF @AidYear IS NULL OR @AidYear NOT LIKE '[12][0-9][0-9][0-9]-[12][0-9][0-9][0-9]'
        THROW 52202, N'@AidYear must look like 2025-2026.', 1;

    SELECT
        p.[IdNumber], p.[AidYear], p.[FundCode], p.[FundSource], p.[FundType], p.[AwardCount], p.[OfferedAmount],
        p.[AcceptedAmount], p.[DisbursedAmount], p.[CancelledAmount], p.[DeclinedAmount], p.[RemainingAmount]
    FROM [reporting].[vw_FinancialAidPackaging] AS p
    WHERE p.[AidYear] = @AidYear
    ORDER BY p.[IdNumber], p.[FundCode];
END;
