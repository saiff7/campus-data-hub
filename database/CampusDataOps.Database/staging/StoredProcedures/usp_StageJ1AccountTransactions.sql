-- Stages the latest landed version of each J1-Sim account transaction.
CREATE PROCEDURE [staging].[usp_StageJ1AccountTransactions]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

    BEGIN TRY
        WITH [Latest] AS (
            SELECT
                r.[LandingRowId], r.[TransactionId], r.[IdNumber], r.[TermCode], r.[TransactionType], r.[DetailCode],
                r.[Amount], r.[PostedDate], r.[DueDate],
                ROW_NUMBER() OVER (PARTITION BY r.[TransactionId] ORDER BY r.[BatchId] DESC) AS [VersionRank]
            FROM [landing].[J1AccountTransactionRaw] AS r
        )

        SELECT
            l.[LandingRowId], l.[TransactionId], l.[IdNumber], l.[TermCode], l.[TransactionType], l.[DetailCode],
            l.[Amount], l.[PostedDate], l.[DueDate]
        INTO #Staged
        FROM [Latest] AS l
        WHERE l.[VersionRank] = 1
          AND NOT EXISTS (
              SELECT 1
              FROM [staging].[AccountTransaction] AS t
              WHERE t.[TransactionId] = l.[TransactionId] AND t.[LandingRowId] = l.[LandingRowId]
          );

        BEGIN TRANSACTION;

        UPDATE t
        SET t.[LandingRowId] = st.[LandingRowId],
            t.[IdNumber] = st.[IdNumber],
            t.[TermCode] = st.[TermCode],
            t.[TransactionType] = st.[TransactionType],
            t.[DetailCode] = st.[DetailCode],
            t.[Amount] = st.[Amount],
            t.[PostedDate] = st.[PostedDate],
            t.[DueDate] = st.[DueDate],
            t.[LastStagedBatchId] = @BatchId,
            t.[UpdatedAtUtc] = @NowUtc
        FROM [staging].[AccountTransaction] AS t
        INNER JOIN #Staged AS st ON t.[TransactionId] = st.[TransactionId];

        SET @RowsAffected = @@ROWCOUNT;

        INSERT INTO [staging].[AccountTransaction] (
            [TransactionId], [LandingRowId], [IdNumber], [TermCode], [TransactionType], [DetailCode], [Amount],
            [PostedDate], [DueDate], [LastStagedBatchId]
        )
        SELECT
            st.[TransactionId], st.[LandingRowId], st.[IdNumber], st.[TermCode], st.[TransactionType], st.[DetailCode],
            st.[Amount], st.[PostedDate], st.[DueDate], @BatchId AS [LastStagedBatchId]
        FROM #Staged AS st
        WHERE NOT EXISTS (SELECT 1 FROM [staging].[AccountTransaction] AS t WHERE t.[TransactionId] = st.[TransactionId]);

        SET @RowsAffected += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
