-- Stages the latest landed version of each J1-Sim credential award.
CREATE PROCEDURE [staging].[usp_StageJ1Credentials]
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
                r.[LandingRowId], r.[CredentialAwardedId], r.[IdNumber], r.[ProgramCode], r.[TermCode], r.[AwardedDate],
                ROW_NUMBER() OVER (PARTITION BY r.[CredentialAwardedId] ORDER BY r.[BatchId] DESC) AS [VersionRank]
            FROM [landing].[J1CredentialRaw] AS r
        )

        SELECT
            l.[LandingRowId], l.[CredentialAwardedId], l.[IdNumber], l.[ProgramCode], l.[TermCode], l.[AwardedDate]
        INTO #Staged
        FROM [Latest] AS l
        WHERE l.[VersionRank] = 1
          AND NOT EXISTS (
              SELECT 1
              FROM [staging].[CredentialAwarded] AS c
              WHERE c.[CredentialAwardedId] = l.[CredentialAwardedId] AND c.[LandingRowId] = l.[LandingRowId]
          );

        BEGIN TRANSACTION;

        UPDATE c
        SET c.[LandingRowId] = st.[LandingRowId],
            c.[IdNumber] = st.[IdNumber],
            c.[ProgramCode] = st.[ProgramCode],
            c.[TermCode] = st.[TermCode],
            c.[AwardedDate] = st.[AwardedDate],
            c.[LastStagedBatchId] = @BatchId,
            c.[UpdatedAtUtc] = @NowUtc
        FROM [staging].[CredentialAwarded] AS c
        INNER JOIN #Staged AS st ON c.[CredentialAwardedId] = st.[CredentialAwardedId];

        SET @RowsAffected = @@ROWCOUNT;

        INSERT INTO [staging].[CredentialAwarded] (
            [CredentialAwardedId], [LandingRowId], [IdNumber], [ProgramCode], [TermCode], [AwardedDate], [LastStagedBatchId]
        )
        SELECT
            st.[CredentialAwardedId], st.[LandingRowId], st.[IdNumber], st.[ProgramCode], st.[TermCode], st.[AwardedDate],
            @BatchId AS [LastStagedBatchId]
        FROM #Staged AS st
        WHERE NOT EXISTS (
            SELECT 1 FROM [staging].[CredentialAwarded] AS c WHERE c.[CredentialAwardedId] = st.[CredentialAwardedId]
        );

        SET @RowsAffected += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
