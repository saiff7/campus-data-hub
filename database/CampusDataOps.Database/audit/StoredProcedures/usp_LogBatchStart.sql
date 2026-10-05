CREATE PROCEDURE [audit].[usp_LogBatchStart]
    @ProcessName          VARCHAR (100),
    @SourceSystemCode     VARCHAR (20)  = NULL,
    @PreviousWatermarkUtc DATETIME2 (3) = NULL,
    @RequestedAtUtc       DATETIME2 (3) = NULL,
    @BatchId              BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@ProcessName)), '') IS NULL
            THROW 50001, N'ProcessName is required.', 1;

        IF @RequestedAtUtc > @NowUtc
            THROW 50002, N'RequestedAtUtc cannot be in the future.', 1;

        INSERT INTO [audit].[BatchRun] (
            [ProcessName],
            [SourceSystemCode],
            [BatchStatusCode],
            [RequestedAtUtc],
            [StartedAtUtc],
            [PreviousWatermarkUtc]
        )
        VALUES (
            @ProcessName,
            @SourceSystemCode,
            'RUNNING',
            ISNULL(@RequestedAtUtc, @NowUtc),
            @NowUtc,
            @PreviousWatermarkUtc
        );

        SET @BatchId = CAST(SCOPE_IDENTITY() AS BIGINT);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT = 0
            EXEC [audit].[usp_LogError];

        -- 2601 comes from UX_audit_BatchRun_OneRunningPerProcess.
        IF ERROR_NUMBER() = 2601
        BEGIN
            DECLARE @Message NVARCHAR (400) = CONCAT(
                N'A RUNNING batch already exists for process ', @ProcessName,
                N'. Finish or fail it before starting another.'
            );
            THROW 50003, @Message, 1;
        END;

        THROW;
    END CATCH;
END;
