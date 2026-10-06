-- Opens a NIGHTLY_INTEGRATION run. The filtered unique index on audit.BatchRun guarantees at
-- most one RUNNING run; a second start fails with a clear message.
CREATE PROCEDURE [integration].[usp_StartPipelineRun]
    @BatchId BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC [audit].[usp_LogBatchStart] @ProcessName = 'NIGHTLY_INTEGRATION', @BatchId = @BatchId OUTPUT;

    SELECT @BatchId AS [BatchId];
END;
