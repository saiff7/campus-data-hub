-- Lands Slate-Sim applicants and applications changed at or after the previous watermark.
-- Re-reading rows at the watermark boundary is harmless: a row whose hash equals the latest
-- landed version of its key is counted as unchanged and not inserted.
-- Called by landing.usp_RunLandingLoad, which owns batch control and error logging.
CREATE PROCEDURE [landing].[usp_LoadSlateSim]
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
            v.[PersonId], v.[FirstName], v.[MiddleName], v.[LastName], v.[PreferredName], v.[BirthDate],
            v.[Email], v.[Phone], v.[AddressLine1], v.[AddressLine2], v.[City], v.[StateCode],
            v.[PostalCode], v.[CountryCode], v.[SisIdClaim], v.[SourceUpdatedAtUtc],
            h.[RecordHash]
        INTO #Applicant
        FROM [landing].[vw_SourceSlateApplicant] AS v
        CROSS APPLY ( -- noqa: ST05
            SELECT HASHBYTES('SHA2_256', (
                SELECT
                    v.[PersonId], v.[FirstName], v.[MiddleName],
                    v.[LastName], v.[PreferredName], v.[BirthDate],
                    v.[Email], v.[Phone], v.[AddressLine1],
                    v.[AddressLine2], v.[City], v.[StateCode],
                    v.[PostalCode], v.[CountryCode], v.[SisIdClaim]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            )) AS [RecordHash]
        ) AS h
        WHERE @PreviousWatermarkUtc IS NULL OR v.[SourceUpdatedAtUtc] >= @PreviousWatermarkUtc;

        SELECT
            v.[ApplicationId], v.[PersonId], v.[EntryTermCode], v.[StudentType], v.[ApplicationStatus],
            v.[SubmittedAtUtc], v.[DecisionAtUtc], v.[ProgramChoice1], v.[ProgramChoice2], v.[ProgramChoice3],
            v.[ExportQueuedAtUtc], v.[SourceUpdatedAtUtc],
            h.[RecordHash]
        INTO #Application
        FROM [landing].[vw_SourceSlateApplication] AS v
        CROSS APPLY ( -- noqa: ST05
            SELECT HASHBYTES('SHA2_256', (
                SELECT
                    v.[ApplicationId], v.[PersonId], v.[EntryTermCode],
                    v.[StudentType], v.[ApplicationStatus],
                    v.[SubmittedAtUtc], v.[DecisionAtUtc],
                    v.[ProgramChoice1], v.[ProgramChoice2],
                    v.[ProgramChoice3], v.[ExportQueuedAtUtc]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            )) AS [RecordHash]
        ) AS h
        WHERE @PreviousWatermarkUtc IS NULL OR v.[SourceUpdatedAtUtc] >= @PreviousWatermarkUtc;

        SET @RowsRead = (SELECT COUNT(*) FROM #Applicant) + (SELECT COUNT(*) FROM #Application);
        SET @SourceWatermarkUtc = (
            SELECT MAX(w.[SourceUpdatedAtUtc])
            FROM (
                SELECT a.[SourceUpdatedAtUtc] FROM #Applicant AS a
                UNION ALL
                SELECT p.[SourceUpdatedAtUtc] FROM #Application AS p
            ) AS w
        );
        SET @SourceWatermarkUtc = COALESCE(@SourceWatermarkUtc, @PreviousWatermarkUtc, CAST('1900-01-01' AS DATETIME2 (3)));
        SET @RowsInserted = 0;

        BEGIN TRANSACTION;

        INSERT INTO [landing].[SlateApplicantRaw] (
            [BatchId], [PersonId], [FirstName], [MiddleName], [LastName], [PreferredName], [BirthDate],
            [Email], [Phone], [AddressLine1], [AddressLine2], [City], [StateCode], [PostalCode], [CountryCode],
            [SisIdClaim], [SourceUpdatedAtUtc], [RecordHash], [RequestId]
        )
        SELECT
            @BatchId AS [BatchId], s.[PersonId], s.[FirstName], s.[MiddleName], s.[LastName], s.[PreferredName],
            s.[BirthDate], s.[Email], s.[Phone], s.[AddressLine1], s.[AddressLine2], s.[City], s.[StateCode],
            s.[PostalCode], s.[CountryCode], s.[SisIdClaim], s.[SourceUpdatedAtUtc], s.[RecordHash],
            'landing.vw_SourceSlateApplicant' AS [RequestId]
        FROM #Applicant AS s
        OUTER APPLY (
            SELECT TOP (1) r.[RecordHash]
            FROM [landing].[SlateApplicantRaw] AS r
            WHERE r.[PersonId] = s.[PersonId]
            ORDER BY r.[BatchId] DESC
        ) AS latest
        WHERE latest.[RecordHash] IS NULL OR latest.[RecordHash] <> s.[RecordHash];

        SET @RowsInserted += @@ROWCOUNT;

        INSERT INTO [landing].[SlateApplicationRaw] (
            [BatchId], [ApplicationId], [PersonId], [EntryTermCode], [StudentType], [ApplicationStatus],
            [SubmittedAtUtc], [DecisionAtUtc], [ProgramChoice1], [ProgramChoice2], [ProgramChoice3],
            [ExportQueuedAtUtc], [SourceUpdatedAtUtc], [RecordHash], [RequestId]
        )
        SELECT
            @BatchId AS [BatchId], s.[ApplicationId], s.[PersonId], s.[EntryTermCode], s.[StudentType],
            s.[ApplicationStatus], s.[SubmittedAtUtc], s.[DecisionAtUtc], s.[ProgramChoice1], s.[ProgramChoice2],
            s.[ProgramChoice3], s.[ExportQueuedAtUtc], s.[SourceUpdatedAtUtc], s.[RecordHash],
            'landing.vw_SourceSlateApplication' AS [RequestId]
        FROM #Application AS s
        OUTER APPLY (
            SELECT TOP (1) r.[RecordHash]
            FROM [landing].[SlateApplicationRaw] AS r
            WHERE r.[ApplicationId] = s.[ApplicationId]
            ORDER BY r.[BatchId] DESC
        ) AS latest
        WHERE latest.[RecordHash] IS NULL OR latest.[RecordHash] <> s.[RecordHash];

        SET @RowsInserted += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
