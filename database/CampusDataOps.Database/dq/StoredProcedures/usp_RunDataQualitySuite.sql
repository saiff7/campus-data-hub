-- Runs every check procedure for one batch in one transaction, so a run's results are complete
-- or absent. A batch already validated returns its existing run instead of duplicating it.
CREATE PROCEDURE [dq].[usp_RunDataQualitySuite]
    @BatchId         BIGINT,
    @ValidationRunId BIGINT = NULL OUTPUT,
    @RowsAffected    INT    = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartedAtUtc DATETIME2 (3) = SYSUTCDATETIME();

    BEGIN TRY
        SET @ValidationRunId = (SELECT vr.[ValidationRunId] FROM [dq].[ValidationRun] AS vr WHERE vr.[BatchId] = @BatchId);
        IF @ValidationRunId IS NOT NULL
        BEGIN
            SET @RowsAffected = 0;
            RETURN;
        END;

        BEGIN TRANSACTION;

        INSERT INTO [dq].[ValidationRun] ([BatchId], [StartedAtUtc], [EndedAtUtc], [RulesEvaluated], [FailuresFound])
        VALUES (@BatchId, @StartedAtUtc, @StartedAtUtc, 0, 0);

        SET @ValidationRunId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC [dq].[usp_CheckApplicantRules] @ValidationRunId = @ValidationRunId;
        EXEC [dq].[usp_CheckDuplicatePeople] @ValidationRunId = @ValidationRunId;
        EXEC [dq].[usp_CheckEnrollmentIntegrity] @ValidationRunId = @ValidationRunId;
        EXEC [dq].[usp_CheckFinancialAidPeriods] @ValidationRunId = @ValidationRunId;
        EXEC [dq].[usp_CheckCrossSystemConsistency] @ValidationRunId = @ValidationRunId;
        EXEC [dq].[usp_CheckAccountControlTotals] @ValidationRunId = @ValidationRunId;
        EXEC [dq].[usp_CheckAcademicConsistency] @ValidationRunId = @ValidationRunId;

        UPDATE vr
        SET vr.[EndedAtUtc] = SYSUTCDATETIME(),
            vr.[RulesEvaluated] = (SELECT COUNT(*) FROM [dq].[RuleExecution] AS x WHERE x.[ValidationRunId] = @ValidationRunId),
            vr.[FailuresFound] = (SELECT COUNT(*) FROM [dq].[RuleResult] AS r WHERE r.[ValidationRunId] = @ValidationRunId)
        FROM [dq].[ValidationRun] AS vr
        WHERE vr.[ValidationRunId] = @ValidationRunId;

        SET @RowsAffected = (SELECT vr.[FailuresFound] FROM [dq].[ValidationRun] AS vr WHERE vr.[ValidationRunId] = @ValidationRunId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
