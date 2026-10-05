-- Lands Directory-Sim accounts changed at or after the previous watermark. Same contract as
-- landing.usp_LoadSlateSim.
CREATE PROCEDURE [landing].[usp_LoadDirectorySim]
    @BatchId              BIGINT,
    @PreviousWatermarkUtc DATETIME2 (3),
    @RowsRead             INT           OUTPUT,
    @RowsInserted         INT           OUTPUT,
    @SourceWatermarkUtc   DATETIME2 (3) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- RecordHash is SHA-256 over the row serialized with FOR JSON (INCLUDE_NULL_VALUES), which
    -- distinguishes NULL from empty and needs no delimiter escaping. The correlated subquery is
    -- per row by design, hence the ST05 suppressions.

    BEGIN TRY
        SELECT
            v.[AccountGuid], v.[SamAccountName], v.[UserPrincipalName], v.[EmployeeId], v.[DisplayName],
            v.[AccountType], v.[IsEnabled], v.[WhenCreatedUtc], v.[GroupNames], v.[SourceUpdatedAtUtc],
            h.[RecordHash]
        INTO #Account
        FROM [landing].[vw_SourceDirectoryAccount] AS v
        CROSS APPLY ( -- noqa: ST05
            SELECT HASHBYTES('SHA2_256', (
                SELECT
                    v.[AccountGuid], v.[SamAccountName],
                    v.[UserPrincipalName], v.[EmployeeId],
                    v.[DisplayName], v.[AccountType], v.[IsEnabled],
                    v.[WhenCreatedUtc], v.[GroupNames]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            )) AS [RecordHash]
        ) AS h
        WHERE @PreviousWatermarkUtc IS NULL OR v.[SourceUpdatedAtUtc] >= @PreviousWatermarkUtc;

        SET @RowsRead = (SELECT COUNT(*) FROM #Account);
        SET @SourceWatermarkUtc = COALESCE(
            (SELECT MAX(a.[SourceUpdatedAtUtc]) FROM #Account AS a),
            @PreviousWatermarkUtc,
            CAST('1900-01-01' AS DATETIME2 (3))
        );

        BEGIN TRANSACTION;

        INSERT INTO [landing].[DirectoryAccountRaw] (
            [BatchId], [AccountGuid], [SamAccountName], [UserPrincipalName], [EmployeeId], [DisplayName],
            [AccountType], [IsEnabled], [WhenCreatedUtc], [GroupNames], [SourceUpdatedAtUtc], [RecordHash], [RequestId]
        )
        SELECT
            @BatchId AS [BatchId], s.[AccountGuid], s.[SamAccountName], s.[UserPrincipalName], s.[EmployeeId],
            s.[DisplayName], s.[AccountType], s.[IsEnabled], s.[WhenCreatedUtc], s.[GroupNames],
            s.[SourceUpdatedAtUtc], s.[RecordHash], 'landing.vw_SourceDirectoryAccount' AS [RequestId]
        FROM #Account AS s
        OUTER APPLY (
            SELECT TOP (1) r.[RecordHash]
            FROM [landing].[DirectoryAccountRaw] AS r
            WHERE r.[AccountGuid] = s.[AccountGuid]
            ORDER BY r.[BatchId] DESC
        ) AS latest
        WHERE latest.[RecordHash] IS NULL OR latest.[RecordHash] <> s.[RecordHash];

        SET @RowsInserted = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
