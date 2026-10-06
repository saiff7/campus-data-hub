-- Stages the latest landed version of each J1-Sim financial aid award.
CREATE PROCEDURE [staging].[usp_StageJ1FinancialAid]
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
                r.[LandingRowId], r.[AwardId], r.[IdNumber], r.[AidYear], r.[TermCode], r.[FundCode], r.[AwardStatus],
                r.[OfferedAmount], r.[AcceptedAmount], r.[DisbursedAmount],
                ROW_NUMBER() OVER (PARTITION BY r.[AwardId] ORDER BY r.[BatchId] DESC) AS [VersionRank]
            FROM [landing].[J1FinancialAidRaw] AS r
        )

        SELECT
            l.[LandingRowId], l.[AwardId], l.[IdNumber], l.[AidYear], l.[TermCode], l.[FundCode], l.[AwardStatus],
            l.[OfferedAmount], l.[AcceptedAmount], l.[DisbursedAmount]
        INTO #Staged
        FROM [Latest] AS l
        WHERE l.[VersionRank] = 1
          AND NOT EXISTS (
              SELECT 1
              FROM [staging].[FinancialAidAward] AS f
              WHERE f.[AwardId] = l.[AwardId] AND f.[LandingRowId] = l.[LandingRowId]
          );

        BEGIN TRANSACTION;

        UPDATE f
        SET f.[LandingRowId] = st.[LandingRowId],
            f.[IdNumber] = st.[IdNumber],
            f.[AidYear] = st.[AidYear],
            f.[TermCode] = st.[TermCode],
            f.[FundCode] = st.[FundCode],
            f.[AwardStatus] = st.[AwardStatus],
            f.[OfferedAmount] = st.[OfferedAmount],
            f.[AcceptedAmount] = st.[AcceptedAmount],
            f.[DisbursedAmount] = st.[DisbursedAmount],
            f.[LastStagedBatchId] = @BatchId,
            f.[UpdatedAtUtc] = @NowUtc
        FROM [staging].[FinancialAidAward] AS f
        INNER JOIN #Staged AS st ON f.[AwardId] = st.[AwardId];

        SET @RowsAffected = @@ROWCOUNT;

        INSERT INTO [staging].[FinancialAidAward] (
            [AwardId], [LandingRowId], [IdNumber], [AidYear], [TermCode], [FundCode], [AwardStatus],
            [OfferedAmount], [AcceptedAmount], [DisbursedAmount], [LastStagedBatchId]
        )
        SELECT
            st.[AwardId], st.[LandingRowId], st.[IdNumber], st.[AidYear], st.[TermCode], st.[FundCode], st.[AwardStatus],
            st.[OfferedAmount], st.[AcceptedAmount], st.[DisbursedAmount], @BatchId AS [LastStagedBatchId]
        FROM #Staged AS st
        WHERE NOT EXISTS (SELECT 1 FROM [staging].[FinancialAidAward] AS f WHERE f.[AwardId] = st.[AwardId]);

        SET @RowsAffected += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
