-- Standardizes the latest landed version of each J1-Sim person into staging.Person, using the
-- same normalization as applicants so matching compares like with like. Only people whose
-- latest landed row changed are written.
CREATE PROCEDURE [staging].[usp_StageJ1People]
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
                r.[LandingRowId], r.[IdNumber], r.[FirstName], r.[MiddleName], r.[LastName], r.[BirthDate],
                r.[Email], r.[Phone], r.[AddressLine1], r.[City], r.[StateCode], r.[PostalCode],
                r.[StudentProgramCode], r.[StudentEntryTermCode], r.[StudentStatus], r.[ResidencyCode],
                r.[MatriculationDate],
                ROW_NUMBER() OVER (PARTITION BY r.[IdNumber] ORDER BY r.[BatchId] DESC) AS [VersionRank]
            FROM [landing].[J1PersonRaw] AS r
        )

        SELECT
            l.[IdNumber],
            l.[LandingRowId],
            l.[FirstName] AS [FirstNameRaw],
            l.[MiddleName] AS [MiddleNameRaw],
            l.[LastName] AS [LastNameRaw],
            l.[BirthDate],
            l.[Email] AS [EmailRaw],
            l.[Phone] AS [PhoneRaw],
            l.[AddressLine1],
            l.[City],
            l.[StateCode],
            l.[PostalCode] AS [PostalCodeRaw],
            l.[StudentProgramCode],
            l.[StudentEntryTermCode],
            l.[StudentStatus],
            l.[ResidencyCode],
            l.[MatriculationDate],
            CAST(CASE
                WHEN LEFT(TRIM(l.[PostalCode]), 5) LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN LEFT(TRIM(l.[PostalCode]), 5)
            END AS CHAR (5)) AS [PostalCode5],
            CAST(CASE WHEN l.[StudentStatus] IS NULL THEN 0 ELSE 1 END AS BIT) AS [HasStudentRecord],
            [integration].[fn_NormalizeName](l.[FirstName]) AS [FirstNameStd],
            [integration].[fn_NormalizeName](l.[LastName]) AS [LastNameStd],
            [integration].[fn_NormalizeEmail](l.[Email]) AS [EmailStd],
            [integration].[fn_NormalizePhone](l.[Phone]) AS [PhoneStd]
        INTO #Staged
        FROM [Latest] AS l
        WHERE l.[VersionRank] = 1
          AND NOT EXISTS (
              SELECT 1 FROM [staging].[Person] AS p WHERE p.[IdNumber] = l.[IdNumber] AND p.[LandingRowId] = l.[LandingRowId]
          );

        BEGIN TRANSACTION;

        UPDATE p
        SET p.[LandingRowId] = st.[LandingRowId],
            p.[FirstNameRaw] = st.[FirstNameRaw],
            p.[FirstNameStd] = st.[FirstNameStd],
            p.[MiddleNameRaw] = st.[MiddleNameRaw],
            p.[LastNameRaw] = st.[LastNameRaw],
            p.[LastNameStd] = st.[LastNameStd],
            p.[BirthDate] = st.[BirthDate],
            p.[EmailRaw] = st.[EmailRaw],
            p.[EmailStd] = st.[EmailStd],
            p.[PhoneRaw] = st.[PhoneRaw],
            p.[PhoneStd] = st.[PhoneStd],
            p.[AddressLine1] = st.[AddressLine1],
            p.[City] = st.[City],
            p.[StateCode] = st.[StateCode],
            p.[PostalCodeRaw] = st.[PostalCodeRaw],
            p.[PostalCode5] = st.[PostalCode5],
            p.[HasStudentRecord] = st.[HasStudentRecord],
            p.[StudentProgramCode] = st.[StudentProgramCode],
            p.[StudentEntryTermCode] = st.[StudentEntryTermCode],
            p.[StudentStatus] = st.[StudentStatus],
            p.[ResidencyCode] = st.[ResidencyCode],
            p.[MatriculationDate] = st.[MatriculationDate],
            p.[LastStagedBatchId] = @BatchId,
            p.[UpdatedAtUtc] = @NowUtc
        FROM [staging].[Person] AS p
        INNER JOIN #Staged AS st ON p.[IdNumber] = st.[IdNumber];

        SET @RowsAffected = @@ROWCOUNT;

        INSERT INTO [staging].[Person] (
            [IdNumber], [LandingRowId], [FirstNameRaw], [FirstNameStd], [MiddleNameRaw], [LastNameRaw],
            [LastNameStd], [BirthDate], [EmailRaw], [EmailStd], [PhoneRaw], [PhoneStd], [AddressLine1], [City],
            [StateCode], [PostalCodeRaw], [PostalCode5], [HasStudentRecord], [StudentProgramCode],
            [StudentEntryTermCode], [StudentStatus], [ResidencyCode], [MatriculationDate], [LastStagedBatchId]
        )
        SELECT
            st.[IdNumber], st.[LandingRowId], st.[FirstNameRaw], st.[FirstNameStd], st.[MiddleNameRaw],
            st.[LastNameRaw], st.[LastNameStd], st.[BirthDate], st.[EmailRaw], st.[EmailStd], st.[PhoneRaw],
            st.[PhoneStd], st.[AddressLine1], st.[City], st.[StateCode], st.[PostalCodeRaw], st.[PostalCode5],
            st.[HasStudentRecord], st.[StudentProgramCode], st.[StudentEntryTermCode], st.[StudentStatus],
            st.[ResidencyCode], st.[MatriculationDate], @BatchId AS [LastStagedBatchId]
        FROM #Staged AS st
        WHERE NOT EXISTS (SELECT 1 FROM [staging].[Person] AS p WHERE p.[IdNumber] = st.[IdNumber]);

        SET @RowsAffected += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
