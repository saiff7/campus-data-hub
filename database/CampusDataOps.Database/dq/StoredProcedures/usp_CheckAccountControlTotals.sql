-- ACCT_DETAIL_TO_TOTAL: staged transaction count and amount per student-term must equal the
-- latest source control total captured at load (J1-Sim stores no balance to compare with).
-- Detail codes name which measure differs; amounts are not copied into results.
CREATE PROCEDURE [dq].[usp_CheckAccountControlTotals]
    @ValidationRunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Evaluations [dq].[RuleEvaluation];
    DECLARE @CheckProcedure NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));

    WITH [LatestTotal] AS (
        SELECT
            ct.[IdNumber],
            ct.[TermCode],
            ct.[TransactionCount],
            ct.[AmountTotal],
            ROW_NUMBER() OVER (PARTITION BY ct.[IdNumber], ct.[TermCode] ORDER BY ct.[BatchId] DESC) AS [VersionRank]
        FROM [landing].[J1AccountControlTotal] AS ct
    ),

    [StagedDetail] AS (
        SELECT t.[IdNumber], t.[TermCode], COUNT(*) AS [TransactionCount], SUM(t.[Amount]) AS [AmountTotal]
        FROM [staging].[AccountTransaction] AS t
        GROUP BY t.[IdNumber], t.[TermCode]
    )

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'ACCT_DETAIL_TO_TOTAL' AS [RuleCode],
        CONCAT(lt.[IdNumber], '|', lt.[TermCode]) AS [RecordKey],
        CAST(CASE
            WHEN ISNULL(sd.[TransactionCount], 0) <> lt.[TransactionCount] OR ISNULL(sd.[AmountTotal], 0) <> lt.[AmountTotal] THEN 1
            ELSE 0
        END AS BIT) AS [IsFailure],
        NULLIF(CONCAT_WS(
            ',',
            CASE WHEN ISNULL(sd.[TransactionCount], 0) <> lt.[TransactionCount] THEN 'COUNT_DIFFERS' END,
            CASE WHEN ISNULL(sd.[AmountTotal], 0) <> lt.[AmountTotal] THEN 'AMOUNT_DIFFERS' END
        ), '') AS [DetailCode]
    FROM [LatestTotal] AS lt
    LEFT JOIN [StagedDetail] AS sd
        ON lt.[IdNumber] = sd.[IdNumber]
       AND lt.[TermCode] = sd.[TermCode]
    WHERE lt.[VersionRank] = 1;

    EXEC [dq].[usp_RecordRuleEvaluations]
        @ValidationRunId = @ValidationRunId, @CheckProcedure = @CheckProcedure, @Evaluations = @Evaluations;
END;
