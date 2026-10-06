-- Call only from a CATCH block, after any transaction owned by the caller has been rolled
-- back. Inside an uncommittable transaction the insert would fail and mask the original
-- error, so that situation is reported explicitly instead of being skipped silently.
CREATE PROCEDURE [audit].[usp_LogError]
    @BatchId     BIGINT = NULL,
    @BatchStepId BIGINT = NULL,
    @ErrorLogId  BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ERROR_NUMBER() IS NULL
        THROW 50020, N'audit.usp_LogError must be called from within a CATCH block.', 1;

    IF XACT_STATE() = -1
        THROW 50021, N'audit.usp_LogError cannot write inside an uncommittable transaction; roll back first.', 1;

    -- The failure being logged may itself be "batch does not exist"; keep the error row
    -- rather than violating the foreign key. The engine message still names the id.
    IF @BatchId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [audit].[BatchRun] AS br WHERE br.[BatchId] = @BatchId)
        SET @BatchId = NULL;

    IF @BatchStepId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [audit].[BatchStep] AS bs WHERE bs.[BatchStepId] = @BatchStepId)
        SET @BatchStepId = NULL;

    INSERT INTO [audit].[ErrorLog] (
        [BatchId],
        [BatchStepId],
        [ErrorNumber],
        [ErrorSeverity],
        [ErrorState],
        [ErrorProcedure],
        [ErrorLine],
        [ErrorMessage]
    )
    VALUES (
        @BatchId,
        @BatchStepId,
        ERROR_NUMBER(),
        ERROR_SEVERITY(),
        ERROR_STATE(),
        ERROR_PROCEDURE(),
        ERROR_LINE(),
        ERROR_MESSAGE()
    );

    SET @ErrorLogId = CAST(SCOPE_IDENTITY() AS BIGINT);
END;
