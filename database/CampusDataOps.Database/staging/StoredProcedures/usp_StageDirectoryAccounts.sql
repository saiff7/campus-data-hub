-- Stages the latest landed version of each Directory-Sim account. EmployeeIdNumber is set only
-- when EmployeeId is exactly seven digits; the raw value is always kept.
CREATE PROCEDURE [staging].[usp_StageDirectoryAccounts]
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
                r.[LandingRowId], r.[AccountGuid], r.[SamAccountName], r.[AccountType], r.[IsEnabled],
                r.[EmployeeId], r.[GroupNames],
                ROW_NUMBER() OVER (PARTITION BY r.[AccountGuid] ORDER BY r.[BatchId] DESC) AS [VersionRank]
            FROM [landing].[DirectoryAccountRaw] AS r
        )

        SELECT
            l.[AccountGuid],
            l.[LandingRowId],
            l.[SamAccountName],
            l.[AccountType],
            l.[IsEnabled],
            l.[EmployeeId] AS [EmployeeIdRaw],
            l.[GroupNames],
            CASE WHEN TRIM(l.[EmployeeId]) LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN CAST(TRIM(l.[EmployeeId]) AS INT) END
                AS [EmployeeIdNumber]
        INTO #Staged
        FROM [Latest] AS l
        WHERE l.[VersionRank] = 1
          AND NOT EXISTS (
              SELECT 1
              FROM [staging].[DirectoryAccount] AS d
              WHERE d.[AccountGuid] = l.[AccountGuid] AND d.[LandingRowId] = l.[LandingRowId]
          );

        BEGIN TRANSACTION;

        UPDATE d
        SET d.[LandingRowId] = st.[LandingRowId],
            d.[SamAccountName] = st.[SamAccountName],
            d.[AccountType] = st.[AccountType],
            d.[IsEnabled] = st.[IsEnabled],
            d.[EmployeeIdRaw] = st.[EmployeeIdRaw],
            d.[EmployeeIdNumber] = st.[EmployeeIdNumber],
            d.[GroupNames] = st.[GroupNames],
            d.[LastStagedBatchId] = @BatchId,
            d.[UpdatedAtUtc] = @NowUtc
        FROM [staging].[DirectoryAccount] AS d
        INNER JOIN #Staged AS st ON d.[AccountGuid] = st.[AccountGuid];

        SET @RowsAffected = @@ROWCOUNT;

        INSERT INTO [staging].[DirectoryAccount] (
            [AccountGuid], [LandingRowId], [SamAccountName], [AccountType], [IsEnabled], [EmployeeIdRaw],
            [EmployeeIdNumber], [GroupNames], [LastStagedBatchId]
        )
        SELECT
            st.[AccountGuid], st.[LandingRowId], st.[SamAccountName], st.[AccountType], st.[IsEnabled],
            st.[EmployeeIdRaw], st.[EmployeeIdNumber], st.[GroupNames], @BatchId AS [LastStagedBatchId]
        FROM #Staged AS st
        WHERE NOT EXISTS (SELECT 1 FROM [staging].[DirectoryAccount] AS d WHERE d.[AccountGuid] = st.[AccountGuid]);

        SET @RowsAffected += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
