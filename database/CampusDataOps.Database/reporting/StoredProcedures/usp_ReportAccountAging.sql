-- R3 as of a date (default today, UTC). Students with no balance and no credit are omitted.
CREATE PROCEDURE [reporting].[usp_ReportAccountAging]
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @AsOfDate = ISNULL(@AsOfDate, CAST(SYSUTCDATETIME() AS DATE));

    SELECT
        a.[IdNumber], a.[AsOfDate], a.[NetBalance], a.[TransactionCount], a.[LastPaymentDate], a.[CurrentAmount],
        a.[Days001To030], a.[Days031To060], a.[Days061To090], a.[Days091Plus], a.[CreditBalance]
    FROM [reporting].[fn_StudentAccountAging](@AsOfDate) AS a
    WHERE a.[NetBalance] <> 0
    ORDER BY a.[IdNumber];
END;
