-- The QUEUE pipeline step as one atomic unit: approve resolved exceptions for retry, then queue
-- ready applications. Returns the number of queue rows inserted, refreshed or cancelled.
CREATE PROCEDURE [integration].[usp_RunQueueStep]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC [integration].[usp_RetryResolvedExceptions] @BatchId = @BatchId;
        EXEC [integration].[usp_QueueAcceptedApplicants] @BatchId = @BatchId, @RowsAffected = @RowsAffected OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
