-- Simulated SIS import interface for admitted applicants
-- (docs/specifications/integration-controls.md). It stands in for a vendor import service and
-- is the only way CampusDataOps writes to J1-Sim.
--   CREATE_PERSON_STUDENT  new person in the integration ID block 8000000-8999999, ACTIVE student
--   CREATE_STUDENT         ACTIVE student for an existing person without one
--   READMIT_STUDENT        existing non-active student reactivated with the new program and term
-- A known idempotency key returns the original ID number without writing anything.
CREATE PROCEDURE [J1Sim].[usp_ReceiveAdmittedApplicant]
    @IdempotencyKey      BINARY (32),
    @SourceApplicationId UNIQUEIDENTIFIER,
    @ActionCode          VARCHAR (30),
    @IdNumber            INT            = NULL,
    @FirstName           NVARCHAR (100),
    @MiddleName          NVARCHAR (100) = NULL,
    @LastName            NVARCHAR (100),
    @BirthDate           DATE,
    @Email               NVARCHAR (320) = NULL,
    @Phone               VARCHAR (20)   = NULL,
    @AddressLine1        NVARCHAR (200) = NULL,
    @City                NVARCHAR (100) = NULL,
    @StateCode           CHAR (2)       = NULL,
    @PostalCode          VARCHAR (10)   = NULL,
    @ProgramCode         VARCHAR (20),
    @EntryTermCode       VARCHAR (10),
    @ResidencyCode       VARCHAR (20),
    @ResultIdNumber      INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @ResultIdNumber = (
            SELECT r.[IdNumber]
            FROM [J1Sim].[IntegrationReceipt] AS r WITH (UPDLOCK, HOLDLOCK)
            WHERE r.[IdempotencyKey] = @IdempotencyKey
        );

        IF @ResultIdNumber IS NOT NULL
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM [J1Sim].[AcademicProgram] AS p WHERE p.[ProgramCode] = @ProgramCode AND p.[IsActive] = 1)
        BEGIN
            SET @Message = CONCAT(N'Program ', ISNULL(@ProgramCode, N'NULL'), N' is not an active J1-Sim program.');
            THROW 51001, @Message, 1;
        END;

        IF NOT EXISTS (
            SELECT 1 FROM [J1Sim].[AcademicTerm] AS t WHERE t.[TermCode] = @EntryTermCode AND t.[IsOpenForAdmission] = 1
        )
        BEGIN
            SET @Message = CONCAT(N'Term ', ISNULL(@EntryTermCode, N'NULL'), N' is not open for admission in J1-Sim.');
            THROW 51002, @Message, 1;
        END;

        IF @ActionCode = 'CREATE_PERSON_STUDENT'
        BEGIN
            SET @ResultIdNumber = (
                SELECT ISNULL(MAX(p.[IdNumber]), 7999999) + 1
                FROM [J1Sim].[Person] AS p WITH (UPDLOCK, HOLDLOCK)
                WHERE p.[IdNumber] >= 8000000 AND p.[IdNumber] <= 8999999
            );

            IF @ResultIdNumber > 8999999
                THROW 51004, N'The integration ID number block 8000000-8999999 is exhausted.', 1;

            INSERT INTO [J1Sim].[Person] (
                [IdNumber], [FirstName], [MiddleName], [LastName], [BirthDate], [Email], [Phone], [AddressLine1],
                [City], [StateCode], [PostalCode], [CreatedAtUtc], [UpdatedAtUtc]
            )
            VALUES (
                @ResultIdNumber, @FirstName, @MiddleName, @LastName, @BirthDate, @Email, @Phone, @AddressLine1,
                @City, @StateCode, @PostalCode, @NowUtc, @NowUtc
            );

            INSERT INTO [J1Sim].[Student] (
                [IdNumber], [ProgramCode], [EntryTermCode], [StudentStatus], [ResidencyCode], [MatriculationDate],
                [CreatedAtUtc], [UpdatedAtUtc]
            )
            VALUES (@ResultIdNumber, @ProgramCode, @EntryTermCode, 'ACTIVE', @ResidencyCode, @Today, @NowUtc, @NowUtc);
        END
        ELSE IF @ActionCode = 'CREATE_STUDENT'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM [J1Sim].[Person] AS p WHERE p.[IdNumber] = @IdNumber)
            BEGIN
                SET @Message = CONCAT(N'J1-Sim person ', ISNULL(CAST(@IdNumber AS NVARCHAR (12)), N'NULL'), N' does not exist.');
                THROW 51005, @Message, 1;
            END;

            IF EXISTS (SELECT 1 FROM [J1Sim].[Student] AS s WHERE s.[IdNumber] = @IdNumber)
            BEGIN
                SET @Message = CONCAT(N'J1-Sim person ', @IdNumber, N' already has a student record.');
                THROW 51006, @Message, 1;
            END;

            INSERT INTO [J1Sim].[Student] (
                [IdNumber], [ProgramCode], [EntryTermCode], [StudentStatus], [ResidencyCode], [MatriculationDate],
                [CreatedAtUtc], [UpdatedAtUtc]
            )
            VALUES (@IdNumber, @ProgramCode, @EntryTermCode, 'ACTIVE', @ResidencyCode, @Today, @NowUtc, @NowUtc);

            SET @ResultIdNumber = @IdNumber;
        END
        ELSE IF @ActionCode = 'READMIT_STUDENT'
        BEGIN
            UPDATE s
            SET s.[ProgramCode] = @ProgramCode,
                s.[EntryTermCode] = @EntryTermCode,
                s.[StudentStatus] = 'ACTIVE',
                s.[ResidencyCode] = @ResidencyCode,
                s.[MatriculationDate] = @Today,
                s.[UpdatedAtUtc] = @NowUtc
            FROM [J1Sim].[Student] AS s
            WHERE s.[IdNumber] = @IdNumber
              AND s.[StudentStatus] <> 'ACTIVE';

            IF @@ROWCOUNT = 0
            BEGIN
                SET @Message = CONCAT(
                    N'J1-Sim person ', ISNULL(CAST(@IdNumber AS NVARCHAR (12)), N'NULL'), N' has no inactive student record to readmit.'
                );
                THROW 51007, @Message, 1;
            END;

            SET @ResultIdNumber = @IdNumber;
        END
        ELSE
        BEGIN
            SET @Message = CONCAT(N'Unknown import action ', ISNULL(@ActionCode, N'NULL'), N'.');
            THROW 51003, @Message, 1;
        END;

        INSERT INTO [J1Sim].[IntegrationReceipt] ([IdempotencyKey], [IdNumber], [ActionCode], [SourceApplicationId], [ReceivedAtUtc])
        VALUES (@IdempotencyKey, @ResultIdNumber, @ActionCode, @SourceApplicationId, @NowUtc);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
