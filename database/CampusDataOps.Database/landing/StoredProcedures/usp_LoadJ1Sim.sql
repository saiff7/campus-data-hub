-- Lands J1-Sim people, enrollments, aid awards, account transactions and account control
-- totals changed at or after the previous watermark. Same contract as landing.usp_LoadSlateSim.
-- A control total is captured for every student-term with a changed transaction, computed
-- over all of that student-term's source transactions.
CREATE PROCEDURE [landing].[usp_LoadJ1Sim]
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
            v.[IdNumber], v.[FirstName], v.[MiddleName], v.[LastName], v.[BirthDate], v.[Email], v.[Phone],
            v.[AddressLine1], v.[City], v.[StateCode], v.[PostalCode], v.[StudentProgramCode],
            v.[StudentEntryTermCode], v.[StudentStatus], v.[ResidencyCode], v.[MatriculationDate],
            v.[SourceUpdatedAtUtc], h.[RecordHash]
        INTO #Person
        FROM [landing].[vw_SourceJ1Person] AS v
        CROSS APPLY ( -- noqa: ST05
            SELECT HASHBYTES('SHA2_256', (
                SELECT
                    v.[IdNumber], v.[FirstName], v.[MiddleName],
                    v.[LastName], v.[BirthDate], v.[Email], v.[Phone],
                    v.[AddressLine1], v.[City], v.[StateCode],
                    v.[PostalCode], v.[StudentProgramCode],
                    v.[StudentEntryTermCode], v.[StudentStatus],
                    v.[ResidencyCode], v.[MatriculationDate]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            )) AS [RecordHash]
        ) AS h
        WHERE @PreviousWatermarkUtc IS NULL OR v.[SourceUpdatedAtUtc] >= @PreviousWatermarkUtc;

        SELECT
            v.[EnrollmentId], v.[IdNumber], v.[CourseSectionId], v.[TermCode], v.[SubjectCode], v.[CourseNumber],
            v.[SectionNumber], v.[CreditHours], v.[RegistrationStatus], v.[RegisteredAtUtc], v.[StatusChangedAtUtc],
            v.[GradeCode], v.[GradePoints], v.[GradePostedAtUtc], v.[SourceUpdatedAtUtc], h.[RecordHash]
        INTO #Enrollment
        FROM [landing].[vw_SourceJ1Enrollment] AS v
        CROSS APPLY ( -- noqa: ST05
            SELECT HASHBYTES('SHA2_256', (
                SELECT
                    v.[EnrollmentId], v.[IdNumber], v.[CourseSectionId],
                    v.[TermCode], v.[SubjectCode], v.[CourseNumber],
                    v.[SectionNumber], v.[CreditHours],
                    v.[RegistrationStatus], v.[RegisteredAtUtc],
                    v.[StatusChangedAtUtc], v.[GradeCode],
                    v.[GradePoints], v.[GradePostedAtUtc]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            )) AS [RecordHash]
        ) AS h
        WHERE @PreviousWatermarkUtc IS NULL OR v.[SourceUpdatedAtUtc] >= @PreviousWatermarkUtc;

        SELECT
            v.[AwardId], v.[IdNumber], v.[AidYear], v.[TermCode], v.[FundCode], v.[AwardStatus], v.[OfferedAmount],
            v.[AcceptedAmount], v.[DisbursedAmount], v.[SourceUpdatedAtUtc], h.[RecordHash]
        INTO #Aid
        FROM [landing].[vw_SourceJ1FinancialAid] AS v
        CROSS APPLY ( -- noqa: ST05
            SELECT HASHBYTES('SHA2_256', (
                SELECT
                    v.[AwardId], v.[IdNumber], v.[AidYear],
                    v.[TermCode], v.[FundCode], v.[AwardStatus],
                    v.[OfferedAmount], v.[AcceptedAmount],
                    v.[DisbursedAmount]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            )) AS [RecordHash]
        ) AS h
        WHERE @PreviousWatermarkUtc IS NULL OR v.[SourceUpdatedAtUtc] >= @PreviousWatermarkUtc;

        SELECT
            v.[TransactionId], v.[IdNumber], v.[TermCode], v.[TransactionType], v.[DetailCode], v.[Amount],
            v.[PostedDate], v.[DueDate], v.[SourceUpdatedAtUtc], h.[RecordHash]
        INTO #Transaction
        FROM [landing].[vw_SourceJ1AccountTransaction] AS v
        CROSS APPLY ( -- noqa: ST05
            SELECT HASHBYTES('SHA2_256', (
                SELECT
                    v.[TransactionId], v.[IdNumber], v.[TermCode],
                    v.[TransactionType], v.[DetailCode], v.[Amount],
                    v.[PostedDate], v.[DueDate]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            )) AS [RecordHash]
        ) AS h
        WHERE @PreviousWatermarkUtc IS NULL OR v.[SourceUpdatedAtUtc] >= @PreviousWatermarkUtc;

        SELECT
            v.[IdNumber], v.[TermCode], CAST(v.[TransactionCount] AS INT) AS [TransactionCount], v.[AmountTotal],
            v.[SourceUpdatedAtUtc], h.[RecordHash]
        INTO #ControlTotal
        FROM [landing].[vw_SourceJ1AccountControlTotal] AS v
        CROSS APPLY ( -- noqa: ST05
            SELECT HASHBYTES('SHA2_256', (
                SELECT
                    v.[IdNumber], v.[TermCode],
                    v.[TransactionCount], v.[AmountTotal]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            )) AS [RecordHash]
        ) AS h
        WHERE @PreviousWatermarkUtc IS NULL OR v.[SourceUpdatedAtUtc] >= @PreviousWatermarkUtc;

        SET @RowsRead = (SELECT COUNT(*) FROM #Person) + (SELECT COUNT(*) FROM #Enrollment) + (SELECT COUNT(*) FROM #Aid)
            + (SELECT COUNT(*) FROM #Transaction) + (SELECT COUNT(*) FROM #ControlTotal);
        SET @SourceWatermarkUtc = (
            SELECT MAX(w.[SourceUpdatedAtUtc])
            FROM (
                SELECT p.[SourceUpdatedAtUtc] FROM #Person AS p
                UNION ALL
                SELECT e.[SourceUpdatedAtUtc] FROM #Enrollment AS e
                UNION ALL
                SELECT a.[SourceUpdatedAtUtc] FROM #Aid AS a
                UNION ALL
                SELECT t.[SourceUpdatedAtUtc] FROM #Transaction AS t
            ) AS w
        );
        SET @SourceWatermarkUtc = COALESCE(@SourceWatermarkUtc, @PreviousWatermarkUtc, CAST('1900-01-01' AS DATETIME2 (3)));
        SET @RowsInserted = 0;

        BEGIN TRANSACTION;

        INSERT INTO [landing].[J1PersonRaw] (
            [BatchId], [IdNumber], [FirstName], [MiddleName], [LastName], [BirthDate], [Email], [Phone],
            [AddressLine1], [City], [StateCode], [PostalCode], [StudentProgramCode], [StudentEntryTermCode],
            [StudentStatus], [ResidencyCode], [MatriculationDate], [SourceUpdatedAtUtc], [RecordHash], [RequestId]
        )
        SELECT
            @BatchId AS [BatchId], s.[IdNumber], s.[FirstName], s.[MiddleName], s.[LastName], s.[BirthDate],
            s.[Email], s.[Phone], s.[AddressLine1], s.[City], s.[StateCode], s.[PostalCode],
            s.[StudentProgramCode], s.[StudentEntryTermCode], s.[StudentStatus], s.[ResidencyCode],
            s.[MatriculationDate], s.[SourceUpdatedAtUtc], s.[RecordHash], 'landing.vw_SourceJ1Person' AS [RequestId]
        FROM #Person AS s
        OUTER APPLY (
            SELECT TOP (1) r.[RecordHash]
            FROM [landing].[J1PersonRaw] AS r
            WHERE r.[IdNumber] = s.[IdNumber]
            ORDER BY r.[BatchId] DESC
        ) AS latest
        WHERE latest.[RecordHash] IS NULL OR latest.[RecordHash] <> s.[RecordHash];

        SET @RowsInserted += @@ROWCOUNT;

        INSERT INTO [landing].[J1EnrollmentRaw] (
            [BatchId], [EnrollmentId], [IdNumber], [CourseSectionId], [TermCode], [SubjectCode], [CourseNumber],
            [SectionNumber], [CreditHours], [RegistrationStatus], [RegisteredAtUtc], [StatusChangedAtUtc],
            [GradeCode], [GradePoints], [GradePostedAtUtc], [SourceUpdatedAtUtc], [RecordHash], [RequestId]
        )
        SELECT
            @BatchId AS [BatchId], s.[EnrollmentId], s.[IdNumber], s.[CourseSectionId], s.[TermCode],
            s.[SubjectCode], s.[CourseNumber], s.[SectionNumber], s.[CreditHours], s.[RegistrationStatus],
            s.[RegisteredAtUtc], s.[StatusChangedAtUtc], s.[GradeCode], s.[GradePoints], s.[GradePostedAtUtc],
            s.[SourceUpdatedAtUtc], s.[RecordHash], 'landing.vw_SourceJ1Enrollment' AS [RequestId]
        FROM #Enrollment AS s
        OUTER APPLY (
            SELECT TOP (1) r.[RecordHash]
            FROM [landing].[J1EnrollmentRaw] AS r
            WHERE r.[EnrollmentId] = s.[EnrollmentId]
            ORDER BY r.[BatchId] DESC
        ) AS latest
        WHERE latest.[RecordHash] IS NULL OR latest.[RecordHash] <> s.[RecordHash];

        SET @RowsInserted += @@ROWCOUNT;

        INSERT INTO [landing].[J1FinancialAidRaw] (
            [BatchId], [AwardId], [IdNumber], [AidYear], [TermCode], [FundCode], [AwardStatus],
            [OfferedAmount], [AcceptedAmount], [DisbursedAmount], [SourceUpdatedAtUtc], [RecordHash], [RequestId]
        )
        SELECT
            @BatchId AS [BatchId], s.[AwardId], s.[IdNumber], s.[AidYear], s.[TermCode], s.[FundCode],
            s.[AwardStatus], s.[OfferedAmount], s.[AcceptedAmount], s.[DisbursedAmount], s.[SourceUpdatedAtUtc],
            s.[RecordHash], 'landing.vw_SourceJ1FinancialAid' AS [RequestId]
        FROM #Aid AS s
        OUTER APPLY (
            SELECT TOP (1) r.[RecordHash]
            FROM [landing].[J1FinancialAidRaw] AS r
            WHERE r.[AwardId] = s.[AwardId]
            ORDER BY r.[BatchId] DESC
        ) AS latest
        WHERE latest.[RecordHash] IS NULL OR latest.[RecordHash] <> s.[RecordHash];

        SET @RowsInserted += @@ROWCOUNT;

        INSERT INTO [landing].[J1AccountTransactionRaw] (
            [BatchId], [TransactionId], [IdNumber], [TermCode], [TransactionType], [DetailCode], [Amount],
            [PostedDate], [DueDate], [SourceUpdatedAtUtc], [RecordHash], [RequestId]
        )
        SELECT
            @BatchId AS [BatchId], s.[TransactionId], s.[IdNumber], s.[TermCode], s.[TransactionType],
            s.[DetailCode], s.[Amount], s.[PostedDate], s.[DueDate], s.[SourceUpdatedAtUtc], s.[RecordHash],
            'landing.vw_SourceJ1AccountTransaction' AS [RequestId]
        FROM #Transaction AS s
        OUTER APPLY (
            SELECT TOP (1) r.[RecordHash]
            FROM [landing].[J1AccountTransactionRaw] AS r
            WHERE r.[TransactionId] = s.[TransactionId]
            ORDER BY r.[BatchId] DESC
        ) AS latest
        WHERE latest.[RecordHash] IS NULL OR latest.[RecordHash] <> s.[RecordHash];

        SET @RowsInserted += @@ROWCOUNT;

        INSERT INTO [landing].[J1AccountControlTotal] (
            [BatchId], [IdNumber], [TermCode], [TransactionCount], [AmountTotal], [SourceUpdatedAtUtc],
            [RecordHash], [RequestId]
        )
        SELECT
            @BatchId AS [BatchId], s.[IdNumber], s.[TermCode], s.[TransactionCount], s.[AmountTotal],
            s.[SourceUpdatedAtUtc], s.[RecordHash], 'landing.vw_SourceJ1AccountControlTotal' AS [RequestId]
        FROM #ControlTotal AS s
        OUTER APPLY (
            SELECT TOP (1) r.[RecordHash]
            FROM [landing].[J1AccountControlTotal] AS r
            WHERE r.[IdNumber] = s.[IdNumber]
              AND r.[TermCode] = s.[TermCode]
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
