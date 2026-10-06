-- Standardizes the latest landed version of every Slate-Sim application and its applicant into
-- staging.Applicant. Every row is recomputed because validation also depends on governed
-- reference data (terms and the program crosswalk); only rows whose values differ are written.
-- Rules: docs/specifications/matching-rules.md (normalization) and integration-controls.md.
CREATE PROCEDURE [staging].[usp_StageSlateApplicants]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @Orphans INT;
    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        WITH [LatestApplication] AS (
            SELECT
                r.[LandingRowId], r.[ApplicationId], r.[PersonId], r.[EntryTermCode], r.[StudentType],
                r.[ApplicationStatus], r.[ProgramChoice1], r.[ExportQueuedAtUtc], r.[RecordHash],
                ROW_NUMBER() OVER (PARTITION BY r.[ApplicationId] ORDER BY r.[BatchId] DESC) AS [VersionRank]
            FROM [landing].[SlateApplicationRaw] AS r
        ),

        [LatestApplicant] AS (
            SELECT
                r.[LandingRowId], r.[PersonId], r.[FirstName], r.[MiddleName], r.[LastName], r.[BirthDate],
                r.[Email], r.[Phone], r.[AddressLine1], r.[City], r.[StateCode], r.[PostalCode], r.[CountryCode],
                r.[SisIdClaim], r.[RecordHash],
                ROW_NUMBER() OVER (PARTITION BY r.[PersonId] ORDER BY r.[BatchId] DESC) AS [VersionRank]
            FROM [landing].[SlateApplicantRaw] AS r
        )

        SELECT
            a.[ApplicationId],
            a.[PersonId] AS [SlatePersonId],
            p.[LandingRowId] AS [ApplicantLandingRowId],
            a.[LandingRowId] AS [ApplicationLandingRowId],
            p.[RecordHash] AS [ApplicantHash],
            a.[RecordHash] AS [ApplicationHash],
            a.[ApplicationStatus],
            a.[StudentType],
            a.[ExportQueuedAtUtc],
            a.[EntryTermCode] AS [EntryTermCodeRaw],
            a.[ProgramChoice1] AS [ProgramChoice1Raw],
            p.[FirstName] AS [FirstNameRaw],
            p.[MiddleName] AS [MiddleNameRaw],
            p.[LastName] AS [LastNameRaw],
            p.[BirthDate],
            p.[Email] AS [EmailRaw],
            p.[Phone] AS [PhoneRaw],
            p.[AddressLine1],
            p.[City],
            p.[StateCode],
            p.[CountryCode],
            p.[PostalCode] AS [PostalCodeRaw],
            p.[SisIdClaim] AS [SisIdClaimRaw]
        INTO #Source
        FROM [LatestApplication] AS a
        LEFT JOIN [LatestApplicant] AS p
            ON a.[PersonId] = p.[PersonId]
           AND p.[VersionRank] = 1
        WHERE a.[VersionRank] = 1;

        -- An application without a landed applicant would be silently dropped by a join; the
        -- source guarantees the person exists, so this indicates a landing defect.
        SET @Orphans = (SELECT COUNT(*) FROM #Source AS s WHERE s.[ApplicantLandingRowId] IS NULL);
        IF @Orphans > 0
        BEGIN
            SET @Message = CONCAT(@Orphans, N' landed applications have no landed applicant person.');
            THROW 50040, @Message, 1;
        END;

        -- Raw and standardized values are listed side by side for review, hence ST06.
        SELECT -- noqa: ST06
            s.[ApplicationId],
            s.[SlatePersonId],
            s.[ApplicantLandingRowId],
            s.[ApplicationLandingRowId],
            HASHBYTES('SHA2_256', s.[ApplicantHash] + s.[ApplicationHash]) AS [SourceHash],
            s.[ApplicationStatus],
            s.[StudentType],
            s.[ExportQueuedAtUtc],
            CAST(CASE
                WHEN (s.[ApplicationStatus] = 'ADMITTED' OR s.[ApplicationStatus] = 'DEPOSITED')
                    AND s.[ExportQueuedAtUtc] IS NOT NULL THEN 1
                ELSE 0
            END AS BIT) AS [IsEligible],
            s.[FirstNameRaw],
            n.[FirstNameStd],
            s.[MiddleNameRaw],
            n.[MiddleNameStd],
            s.[LastNameRaw],
            n.[LastNameStd],
            s.[BirthDate],
            s.[EmailRaw],
            n.[EmailStd],
            CAST(CASE
                WHEN NULLIF(TRIM(s.[EmailRaw]), N'') IS NULL THEN NULL
                WHEN n.[EmailStd] IS NULL THEN 0
                ELSE 1
            END AS BIT) AS [IsEmailValid],
            s.[PhoneRaw],
            n.[PhoneStd],
            CAST(CASE
                WHEN NULLIF(TRIM(s.[PhoneRaw]), N'') IS NULL THEN NULL
                WHEN n.[PhoneStd] IS NULL THEN 0
                ELSE 1
            END AS BIT) AS [IsPhoneValid],
            s.[AddressLine1],
            s.[City],
            s.[StateCode],
            s.[CountryCode],
            s.[PostalCodeRaw],
            CAST(CASE
                WHEN LEFT(TRIM(s.[PostalCodeRaw]), 5) LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN LEFT(TRIM(s.[PostalCodeRaw]), 5)
            END AS CHAR (5)) AS [PostalCode5],
            CASE
                WHEN s.[CountryCode] IS NOT NULL AND s.[CountryCode] <> 'US' THEN 'INTERNATIONAL'
                WHEN s.[StateCode] IS NULL OR s.[StateCode] = 'MA' THEN 'IN_STATE'
                ELSE 'OUT_OF_STATE'
            END AS [ResidencyCode],
            s.[SisIdClaimRaw],
            CASE WHEN TRIM(s.[SisIdClaimRaw]) LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN CAST(TRIM(s.[SisIdClaimRaw]) AS INT) END
                AS [SisIdClaim],
            CAST(CASE
                WHEN NULLIF(TRIM(s.[SisIdClaimRaw]), '') IS NULL THEN NULL
                WHEN TRIM(s.[SisIdClaimRaw]) LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN 1
                ELSE 0
            END AS BIT) AS [IsSisIdClaimValid],
            s.[EntryTermCodeRaw],
            CASE WHEN t.[IsOpenForAdmission] = 1 THEN t.[TermCode] END AS [EntryTermCode],
            CASE
                WHEN NULLIF(TRIM(s.[EntryTermCodeRaw]), '') IS NULL THEN 'MISSING'
                WHEN t.[TermCode] IS NULL THEN 'UNKNOWN_TERM'
                WHEN t.[IsOpenForAdmission] = 0 THEN 'CLOSED_TERM'
            END AS [TermValidationCode],
            s.[ProgramChoice1Raw],
            CASE WHEN pc.[IsActive] = 1 THEN pc.[J1ProgramCode] END AS [J1ProgramCode],
            CASE
                WHEN NULLIF(TRIM(s.[ProgramChoice1Raw]), '') IS NULL THEN 'MISSING'
                WHEN pc.[SlateProgramCode] IS NULL THEN 'NOT_IN_CROSSWALK'
                WHEN pc.[IsActive] = 0 THEN 'INACTIVE'
            END AS [ProgramValidationCode],
            NULLIF(CONCAT_WS(
                ',',
                CASE WHEN n.[FirstNameStd] IS NULL THEN 'FIRST_NAME' END,
                CASE WHEN n.[LastNameStd] IS NULL THEN 'LAST_NAME' END,
                CASE WHEN s.[BirthDate] IS NULL THEN 'BIRTH_DATE' END,
                CASE WHEN NULLIF(TRIM(s.[EntryTermCodeRaw]), '') IS NULL THEN 'ENTRY_TERM' END,
                CASE WHEN NULLIF(TRIM(s.[ProgramChoice1Raw]), '') IS NULL THEN 'PROGRAM' END
            ), '') AS [MissingRequiredFields]
        INTO #Staged
        FROM #Source AS s
        -- Normalize each value once per row; the results are used more than once below.
        CROSS APPLY ( -- noqa: ST05
            SELECT
                [integration].[fn_NormalizeName](s.[FirstNameRaw]) AS [FirstNameStd],
                [integration].[fn_NormalizeName](s.[MiddleNameRaw]) AS [MiddleNameStd],
                [integration].[fn_NormalizeName](s.[LastNameRaw]) AS [LastNameStd],
                [integration].[fn_NormalizeEmail](s.[EmailRaw]) AS [EmailStd],
                [integration].[fn_NormalizePhone](s.[PhoneRaw]) AS [PhoneStd]
        ) AS n
        LEFT JOIN [reference].[AcademicTerm] AS t ON TRIM(s.[EntryTermCodeRaw]) = t.[TermCode]
        LEFT JOIN [reference].[ProgramCrosswalk] AS pc ON TRIM(s.[ProgramChoice1Raw]) = pc.[SlateProgramCode];

        -- Duplicate applications: eligible applications sharing a person and entry term.
        SELECT
            st.[ApplicationId],
            CASE
                WHEN st.[IsEligible] = 1 AND NULLIF(TRIM(st.[EntryTermCodeRaw]), '') IS NOT NULL
                    THEN COUNT(*) OVER (PARTITION BY st.[IsEligible], st.[SlatePersonId], TRIM(st.[EntryTermCodeRaw]))
                ELSE 1
            END AS [DuplicateApplicationCount]
        INTO #Duplicate
        FROM #Staged AS st;

        BEGIN TRANSACTION;

        UPDATE a
        SET a.[SlatePersonId] = st.[SlatePersonId],
            a.[ApplicantLandingRowId] = st.[ApplicantLandingRowId],
            a.[ApplicationLandingRowId] = st.[ApplicationLandingRowId],
            a.[SourceHash] = st.[SourceHash],
            a.[ApplicationStatus] = st.[ApplicationStatus],
            a.[StudentType] = st.[StudentType],
            a.[ExportQueuedAtUtc] = st.[ExportQueuedAtUtc],
            a.[IsEligible] = st.[IsEligible],
            a.[FirstNameRaw] = st.[FirstNameRaw],
            a.[FirstNameStd] = st.[FirstNameStd],
            a.[MiddleNameRaw] = st.[MiddleNameRaw],
            a.[MiddleNameStd] = st.[MiddleNameStd],
            a.[LastNameRaw] = st.[LastNameRaw],
            a.[LastNameStd] = st.[LastNameStd],
            a.[BirthDate] = st.[BirthDate],
            a.[EmailRaw] = st.[EmailRaw],
            a.[EmailStd] = st.[EmailStd],
            a.[IsEmailValid] = st.[IsEmailValid],
            a.[PhoneRaw] = st.[PhoneRaw],
            a.[PhoneStd] = st.[PhoneStd],
            a.[IsPhoneValid] = st.[IsPhoneValid],
            a.[AddressLine1] = st.[AddressLine1],
            a.[City] = st.[City],
            a.[StateCode] = st.[StateCode],
            a.[CountryCode] = st.[CountryCode],
            a.[PostalCodeRaw] = st.[PostalCodeRaw],
            a.[PostalCode5] = st.[PostalCode5],
            a.[ResidencyCode] = st.[ResidencyCode],
            a.[SisIdClaimRaw] = st.[SisIdClaimRaw],
            a.[SisIdClaim] = st.[SisIdClaim],
            a.[IsSisIdClaimValid] = st.[IsSisIdClaimValid],
            a.[EntryTermCodeRaw] = st.[EntryTermCodeRaw],
            a.[EntryTermCode] = st.[EntryTermCode],
            a.[TermValidationCode] = st.[TermValidationCode],
            a.[ProgramChoice1Raw] = st.[ProgramChoice1Raw],
            a.[J1ProgramCode] = st.[J1ProgramCode],
            a.[ProgramValidationCode] = st.[ProgramValidationCode],
            a.[MissingRequiredFields] = st.[MissingRequiredFields],
            a.[DuplicateApplicationCount] = d.[DuplicateApplicationCount],
            a.[LastStagedBatchId] = @BatchId,
            a.[UpdatedAtUtc] = @NowUtc
        FROM [staging].[Applicant] AS a
        INNER JOIN #Staged AS st ON a.[ApplicationId] = st.[ApplicationId]
        INNER JOIN #Duplicate AS d ON st.[ApplicationId] = d.[ApplicationId]
        -- NULL-safe change detection through correlated references, which SQLFluff RF01 cannot resolve.
        -- noqa: disable=RF01
        WHERE EXISTS (
            SELECT
                st.[SlatePersonId], st.[ApplicantLandingRowId], st.[ApplicationLandingRowId], st.[SourceHash],
                st.[ApplicationStatus], st.[StudentType], st.[ExportQueuedAtUtc], st.[IsEligible], st.[FirstNameRaw],
                st.[FirstNameStd], st.[MiddleNameRaw], st.[MiddleNameStd], st.[LastNameRaw], st.[LastNameStd],
                st.[BirthDate], st.[EmailRaw], st.[EmailStd], st.[IsEmailValid], st.[PhoneRaw], st.[PhoneStd],
                st.[IsPhoneValid], st.[AddressLine1], st.[City], st.[StateCode], st.[CountryCode], st.[PostalCodeRaw],
                st.[PostalCode5], st.[ResidencyCode], st.[SisIdClaimRaw], st.[SisIdClaim], st.[IsSisIdClaimValid],
                st.[EntryTermCodeRaw], st.[EntryTermCode], st.[TermValidationCode], st.[ProgramChoice1Raw],
                st.[J1ProgramCode], st.[ProgramValidationCode], st.[MissingRequiredFields], d.[DuplicateApplicationCount]
            EXCEPT
            SELECT
                a.[SlatePersonId], a.[ApplicantLandingRowId], a.[ApplicationLandingRowId], a.[SourceHash],
                a.[ApplicationStatus], a.[StudentType], a.[ExportQueuedAtUtc], a.[IsEligible], a.[FirstNameRaw],
                a.[FirstNameStd], a.[MiddleNameRaw], a.[MiddleNameStd], a.[LastNameRaw], a.[LastNameStd],
                a.[BirthDate], a.[EmailRaw], a.[EmailStd], a.[IsEmailValid], a.[PhoneRaw], a.[PhoneStd],
                a.[IsPhoneValid], a.[AddressLine1], a.[City], a.[StateCode], a.[CountryCode], a.[PostalCodeRaw],
                a.[PostalCode5], a.[ResidencyCode], a.[SisIdClaimRaw], a.[SisIdClaim], a.[IsSisIdClaimValid],
                a.[EntryTermCodeRaw], a.[EntryTermCode], a.[TermValidationCode], a.[ProgramChoice1Raw],
                a.[J1ProgramCode], a.[ProgramValidationCode], a.[MissingRequiredFields], a.[DuplicateApplicationCount]
        );
        -- noqa: enable=RF01

        SET @RowsAffected = @@ROWCOUNT;

        INSERT INTO [staging].[Applicant] (
            [ApplicationId], [SlatePersonId], [ApplicantLandingRowId], [ApplicationLandingRowId], [SourceHash],
            [ApplicationStatus], [StudentType], [ExportQueuedAtUtc], [IsEligible], [FirstNameRaw], [FirstNameStd],
            [MiddleNameRaw], [MiddleNameStd], [LastNameRaw], [LastNameStd], [BirthDate], [EmailRaw], [EmailStd],
            [IsEmailValid], [PhoneRaw], [PhoneStd], [IsPhoneValid], [AddressLine1], [City], [StateCode],
            [CountryCode], [PostalCodeRaw], [PostalCode5], [ResidencyCode], [SisIdClaimRaw], [SisIdClaim],
            [IsSisIdClaimValid], [EntryTermCodeRaw], [EntryTermCode], [TermValidationCode], [ProgramChoice1Raw],
            [J1ProgramCode], [ProgramValidationCode], [MissingRequiredFields], [DuplicateApplicationCount],
            [FirstStagedBatchId], [LastStagedBatchId]
        )
        SELECT
            st.[ApplicationId], st.[SlatePersonId], st.[ApplicantLandingRowId], st.[ApplicationLandingRowId],
            st.[SourceHash], st.[ApplicationStatus], st.[StudentType], st.[ExportQueuedAtUtc], st.[IsEligible],
            st.[FirstNameRaw], st.[FirstNameStd], st.[MiddleNameRaw], st.[MiddleNameStd], st.[LastNameRaw],
            st.[LastNameStd], st.[BirthDate], st.[EmailRaw], st.[EmailStd], st.[IsEmailValid], st.[PhoneRaw],
            st.[PhoneStd], st.[IsPhoneValid], st.[AddressLine1], st.[City], st.[StateCode], st.[CountryCode],
            st.[PostalCodeRaw], st.[PostalCode5], st.[ResidencyCode], st.[SisIdClaimRaw], st.[SisIdClaim],
            st.[IsSisIdClaimValid], st.[EntryTermCodeRaw], st.[EntryTermCode], st.[TermValidationCode],
            st.[ProgramChoice1Raw], st.[J1ProgramCode], st.[ProgramValidationCode], st.[MissingRequiredFields],
            d.[DuplicateApplicationCount], @BatchId AS [FirstStagedBatchId], @BatchId AS [LastStagedBatchId]
        FROM #Staged AS st
        INNER JOIN #Duplicate AS d ON st.[ApplicationId] = d.[ApplicationId]
        WHERE NOT EXISTS (SELECT 1 FROM [staging].[Applicant] AS a WHERE a.[ApplicationId] = st.[ApplicationId]);

        SET @RowsAffected += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
