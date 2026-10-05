CREATE PROCEDURE [audit].[usp_LogStepEnd]
    @BatchStepId         BIGINT,
    @BatchStepStatusCode VARCHAR (20),
    @RowsAffected        INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1
            FROM [reference].[BatchStepStatus] AS s
            WHERE s.[BatchStepStatusCode] = @BatchStepStatusCode
              AND s.[IsTerminal] = 1
        )
        BEGIN
            SET @Message = CONCAT(N'Step status ', ISNULL(@BatchStepStatusCode, N'NULL'), N' is not a terminal status.');
            THROW 50007, @Message, 1;
        END;

        UPDATE bs
        SET bs.[BatchStepStatusCode] = @BatchStepStatusCode,
            bs.[EndedAtUtc] = @NowUtc,
            bs.[RowsAffected] = @RowsAffected,
            bs.[UpdatedAtUtc] = @NowUtc
        FROM [audit].[BatchStep] AS bs
        WHERE bs.[BatchStepId] = @BatchStepId
          AND bs.[BatchStepStatusCode] = 'RUNNING';

        IF @@ROWCOUNT = 0
        BEGIN
            SET @Message = CONCAT(N'Batch step ', @BatchStepId, N' does not exist or is not RUNNING.');
            THROW 50008, @Message, 1;
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT = 0
            EXEC [audit].[usp_LogError] @BatchStepId = @BatchStepId;

        THROW;
    END CATCH;
END;
