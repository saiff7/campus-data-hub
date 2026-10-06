-- Records the start of one attempt of a step within a RUNNING batch. Attempts are numbered
-- per batch and step, so a step retried inside the same batch keeps its earlier failures.
CREATE PROCEDURE [audit].[usp_LogStepStart]
    @BatchId     BIGINT,
    @StepName    VARCHAR (100),
    @StepOrder   SMALLINT,
    @BatchStepId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1 FROM [audit].[BatchRun] AS br WHERE br.[BatchId] = @BatchId AND br.[BatchStatusCode] = 'RUNNING'
        )
        BEGIN
            SET @Message = CONCAT(N'Batch ', @BatchId, N' does not exist or is not RUNNING.');
            THROW 50006, @Message, 1;
        END;

        INSERT INTO [audit].[BatchStep] (
            [BatchId], [StepName], [StepOrder], [AttemptNumber], [BatchStepStatusCode], [StartedAtUtc]
        )
        SELECT
            @BatchId AS [BatchId],
            @StepName AS [StepName],
            @StepOrder AS [StepOrder],
            ISNULL(MAX(bs.[AttemptNumber]), 0) + 1 AS [AttemptNumber],
            'RUNNING' AS [BatchStepStatusCode],
            SYSUTCDATETIME() AS [StartedAtUtc]
        FROM [audit].[BatchStep] AS bs WITH (UPDLOCK, HOLDLOCK)
        WHERE bs.[BatchId] = @BatchId
          AND bs.[StepName] = @StepName;

        SET @BatchStepId = CAST(SCOPE_IDENTITY() AS BIGINT);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT = 0
            EXEC [audit].[usp_LogError] @BatchId = @BatchId;

        THROW;
    END CATCH;
END;
