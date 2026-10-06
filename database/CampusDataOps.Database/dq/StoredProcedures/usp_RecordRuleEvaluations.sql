-- Writes one check procedure's evaluations: a RuleExecution row for every active, effective
-- rule that dq.Rule assigns to @CheckProcedure (zero evaluated records included, so the
-- scorecard is complete) and a RuleResult row per failing record. Evaluations for inactive or
-- not-yet-effective rules are discarded, which is how a rule is switched off.
CREATE PROCEDURE [dq].[usp_RecordRuleEvaluations]
    @ValidationRunId BIGINT,
    @CheckProcedure  NVARCHAR (256),
    @Evaluations     [dq].[RuleEvaluation] READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Aggregate before the outer join so a rule with nothing to evaluate does not aggregate NULLs.
        WITH [Totals] AS (
            SELECT ev.[RuleCode], COUNT(*) AS [RecordsEvaluated], SUM(CAST(ev.[IsFailure] AS INT)) AS [RecordsFailed]
            FROM @Evaluations AS ev
            GROUP BY ev.[RuleCode]
        )

        INSERT INTO [dq].[RuleExecution] ([ValidationRunId], [RuleCode], [RecordsEvaluated], [RecordsFailed])
        SELECT
            @ValidationRunId AS [ValidationRunId],
            r.[RuleCode],
            ISNULL(t.[RecordsEvaluated], 0) AS [RecordsEvaluated],
            ISNULL(t.[RecordsFailed], 0) AS [RecordsFailed]
        FROM [dq].[Rule] AS r
        LEFT JOIN [Totals] AS t ON r.[RuleCode] = t.[RuleCode]
        WHERE r.[IsActive] = 1
          AND r.[EffectiveFrom] <= @Today
          AND r.[CheckProcedure] = @CheckProcedure;

        INSERT INTO [dq].[RuleResult] ([ValidationRunId], [RuleCode], [RecordKey], [DetailCode])
        SELECT @ValidationRunId AS [ValidationRunId], ev.[RuleCode], ev.[RecordKey], ev.[DetailCode]
        FROM @Evaluations AS ev
        INNER JOIN [dq].[RuleExecution] AS x
            ON x.[ValidationRunId] = @ValidationRunId
           AND ev.[RuleCode] = x.[RuleCode]
        WHERE ev.[IsFailure] = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
