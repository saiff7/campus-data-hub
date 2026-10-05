-- Runs one step of a NIGHTLY_INTEGRATION run (docs/specifications/integration-controls.md).
-- @BatchId defaults to the single RUNNING nightly run, which is how SQL Server Agent steps,
-- running in separate sessions, share a run without session state. A step runs only when every
-- earlier step in the run has SUCCEEDED or been SKIPPED; a step that already succeeded is not
-- repeated. Each attempt is logged in audit.BatchStep. On failure the error is logged against
-- the batch and step, the step and the run are closed FAILED, and the error is re-thrown so the
-- Agent job stops. NOTIFY closes the run SUCCEEDED with its reconciliation counts.
CREATE PROCEDURE [integration].[usp_RunPipelineStep]
    @StepCode VARCHAR (20),
    @BatchId  BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StepOrder SMALLINT;
    DECLARE @BatchStepId BIGINT;
    DECLARE @RowsAffected INT = 0;
    DECLARE @StepRows INT;
    DECLARE @Message NVARCHAR (400);
    DECLARE @Eligible INT;
    DECLARE @Created INT;
    DECLARE @Matched INT;
    DECLARE @Unchanged INT;
    DECLARE @Rejected INT;
    DECLARE @OpenExceptions INT;

    BEGIN TRY
        IF @BatchId IS NULL
            SET @BatchId = (
                SELECT br.[BatchId]
                FROM [audit].[BatchRun] AS br
                WHERE br.[ProcessName] = 'NIGHTLY_INTEGRATION' AND br.[BatchStatusCode] = 'RUNNING'
            );

        IF NOT EXISTS (
            SELECT 1
            FROM [audit].[BatchRun] AS br
            WHERE br.[BatchId] = @BatchId AND br.[ProcessName] = 'NIGHTLY_INTEGRATION' AND br.[BatchStatusCode] = 'RUNNING'
        )
            THROW 50500, N'No RUNNING NIGHTLY_INTEGRATION run; start one with integration.usp_StartPipelineRun or open a recovery run.', 1;

        SET @StepOrder = (SELECT ps.[StepOrder] FROM [reference].[PipelineStep] AS ps WHERE ps.[StepCode] = @StepCode);
        IF @StepOrder IS NULL
        BEGIN
            SET @Message = CONCAT(N'Unknown pipeline step ', ISNULL(@StepCode, N'NULL'), N'.');
            THROW 50501, @Message, 1;
        END;

        IF EXISTS (
            SELECT 1
            FROM [reference].[PipelineStep] AS ps
            WHERE ps.[StepOrder] < @StepOrder
              AND NOT EXISTS (
                  SELECT 1
                  FROM [audit].[BatchStep] AS bs
                  WHERE bs.[BatchId] = @BatchId
                    AND bs.[StepName] = ps.[StepCode]
                    AND (bs.[BatchStepStatusCode] = 'SUCCEEDED' OR bs.[BatchStepStatusCode] = 'SKIPPED')
              )
        )
        BEGIN
            SET @Message = CONCAT(N'Step ', @StepCode, N' cannot run before every earlier step of batch ', @BatchId, N' has succeeded.');
            THROW 50502, @Message, 1;
        END;

        IF EXISTS (
            SELECT 1
            FROM [audit].[BatchStep] AS bs
            WHERE bs.[BatchId] = @BatchId AND bs.[StepName] = @StepCode AND bs.[BatchStepStatusCode] = 'SUCCEEDED'
        )
        BEGIN
            PRINT CONCAT(N'Step ', @StepCode, N' already succeeded in batch ', @BatchId, N'; nothing to do.');
            RETURN;
        END;
    END TRY
    BEGIN CATCH
        EXEC [audit].[usp_LogError] @BatchId = @BatchId;
        THROW;
    END CATCH;

    EXEC [audit].[usp_LogStepStart]
        @BatchId = @BatchId, @StepName = @StepCode, @StepOrder = @StepOrder, @BatchStepId = @BatchStepId OUTPUT;

    BEGIN TRY
        IF @StepCode = 'LOAD'
        BEGIN
            EXEC [landing].[usp_RunLandingLoad] @SourceSystemCode = 'SLATE_SIM', @ParentBatchId = @BatchId;
            EXEC [landing].[usp_RunLandingLoad] @SourceSystemCode = 'J1_SIM', @ParentBatchId = @BatchId;
            EXEC [landing].[usp_RunLandingLoad] @SourceSystemCode = 'DIRECTORY_SIM', @ParentBatchId = @BatchId;
            SET @RowsAffected = (
                SELECT ISNULL(SUM(br.[RowsInserted]), 0) FROM [audit].[BatchRun] AS br WHERE br.[ParentBatchId] = @BatchId
            );
        END
        ELSE IF @StepCode = 'STAGE'
        BEGIN
            EXEC [staging].[usp_StageSlateApplicants] @BatchId = @BatchId, @RowsAffected = @StepRows OUTPUT;
            SET @RowsAffected += @StepRows;
            EXEC [staging].[usp_StageJ1People] @BatchId = @BatchId, @RowsAffected = @StepRows OUTPUT;
            SET @RowsAffected += @StepRows;
            EXEC [staging].[usp_StageDirectoryAccounts] @BatchId = @BatchId, @RowsAffected = @StepRows OUTPUT;
            SET @RowsAffected += @StepRows;
            EXEC [staging].[usp_StageJ1Enrollments] @BatchId = @BatchId, @RowsAffected = @StepRows OUTPUT;
            SET @RowsAffected += @StepRows;
            EXEC [staging].[usp_StageJ1FinancialAid] @BatchId = @BatchId, @RowsAffected = @StepRows OUTPUT;
            SET @RowsAffected += @StepRows;
            EXEC [staging].[usp_StageJ1AccountTransactions] @BatchId = @BatchId, @RowsAffected = @StepRows OUTPUT;
            SET @RowsAffected += @StepRows;
        END
        ELSE IF @StepCode = 'DATA_QUALITY'
            EXEC [dq].[usp_RunDataQualitySuite] @BatchId = @BatchId, @RowsAffected = @RowsAffected OUTPUT;
        ELSE IF @StepCode = 'MATCH'
            EXEC [integration].[usp_RunMatchStep] @BatchId = @BatchId, @RowsAffected = @RowsAffected OUTPUT;
        ELSE IF @StepCode = 'QUEUE'
            EXEC [integration].[usp_RunQueueStep] @BatchId = @BatchId, @RowsAffected = @RowsAffected OUTPUT;
        ELSE IF @StepCode = 'PROCESS'
            EXEC [integration].[usp_ProcessOutboundQueue]
                @BatchId = @BatchId, @BatchStepId = @BatchStepId, @RowsAffected = @RowsAffected OUTPUT;
        ELSE IF @StepCode = 'RECONCILE'
            EXEC [integration].[usp_ReconcileSlateToJ1] @BatchId = @BatchId, @RowsAffected = @RowsAffected OUTPUT;
        ELSE IF @StepCode = 'NOTIFY'
            EXEC [integration].[usp_PublishRunSummary] @BatchId = @BatchId;
        ELSE
        BEGIN
            SET @Message = CONCAT(N'Pipeline step ', @StepCode, N' has no implementation.');
            THROW 50503, @Message, 1;
        END;

        EXEC [audit].[usp_LogStepEnd] @BatchStepId = @BatchStepId, @BatchStepStatusCode = 'SUCCEEDED', @RowsAffected = @RowsAffected;

        IF @StepCode = 'NOTIFY'
        BEGIN
            SELECT
                @Eligible = rr.[SourceEligible],
                @Created = rr.[Created],
                @Matched = rr.[Matched],
                @Unchanged = rr.[Unchanged],
                @Rejected = rr.[Rejected]
            FROM [integration].[ReconciliationResult] AS rr
            WHERE rr.[BatchId] = @BatchId;

            SET @OpenExceptions = (SELECT COUNT(*) FROM [integration].[vw_OpenExceptionWorklist]);

            EXEC [audit].[usp_LogBatchEnd]
                @BatchId = @BatchId,
                @BatchStatusCode = 'SUCCEEDED',
                @RowsRead = @Eligible,
                @RowsInserted = @Created,
                @RowsUpdated = @Matched,
                @RowsUnchanged = @Unchanged,
                @RowsRejected = @Rejected,
                @ExceptionCount = @OpenExceptions;
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        EXEC [audit].[usp_LogError] @BatchId = @BatchId, @BatchStepId = @BatchStepId;
        EXEC [audit].[usp_LogStepEnd] @BatchStepId = @BatchStepId, @BatchStepStatusCode = 'FAILED';
        EXEC [audit].[usp_LogBatchEnd] @BatchId = @BatchId, @BatchStatusCode = 'FAILED';

        THROW;
    END CATCH;
END;
