-- Adapter between the outbound queue and the J1-Sim import interface: the single place
-- CampusDataOps calls into J1-Sim, and the seam tests replace with tSQLt.SpyProcedure.
-- The phone is sent in the SIS's NNN-NNN-NNNN display format.
CREATE PROCEDURE [integration].[usp_WriteApplicantToSis]
    @QueueId        BIGINT,
    @ResultIdNumber INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdempotencyKey BINARY (32);
    DECLARE @ApplicationId UNIQUEIDENTIFIER;
    DECLARE @ActionCode VARCHAR (30);
    DECLARE @TargetIdNumber INT;
    DECLARE @FirstName NVARCHAR (100);
    DECLARE @MiddleName NVARCHAR (100);
    DECLARE @LastName NVARCHAR (100);
    DECLARE @BirthDate DATE;
    DECLARE @Email NVARCHAR (320);
    DECLARE @Phone VARCHAR (20);
    DECLARE @AddressLine1 NVARCHAR (200);
    DECLARE @City NVARCHAR (100);
    DECLARE @StateCode CHAR (2);
    DECLARE @PostalCode VARCHAR (10);
    DECLARE @ProgramCode VARCHAR (20);
    DECLARE @EntryTermCode VARCHAR (10);
    DECLARE @ResidencyCode VARCHAR (20);
    DECLARE @Message NVARCHAR (400);

    SELECT
        @IdempotencyKey = q.[IdempotencyKey],
        @ApplicationId = q.[ApplicationId],
        @ActionCode = q.[ActionCode],
        @TargetIdNumber = q.[TargetIdNumber],
        @FirstName = q.[FirstName],
        @MiddleName = q.[MiddleName],
        @LastName = q.[LastName],
        @BirthDate = q.[BirthDate],
        @Email = q.[Email],
        @Phone = CASE
            WHEN q.[Phone] IS NOT NULL THEN CONCAT(LEFT(q.[Phone], 3), '-', SUBSTRING(q.[Phone], 4, 3), '-', RIGHT(q.[Phone], 4))
        END,
        @AddressLine1 = q.[AddressLine1],
        @City = q.[City],
        @StateCode = q.[StateCode],
        @PostalCode = q.[PostalCode],
        @ProgramCode = q.[J1ProgramCode],
        @EntryTermCode = q.[EntryTermCode],
        @ResidencyCode = q.[ResidencyCode]
    FROM [integration].[OutboundStudentQueue] AS q
    WHERE q.[QueueId] = @QueueId;

    IF @IdempotencyKey IS NULL
    BEGIN
        SET @Message = CONCAT(N'Outbound queue row ', @QueueId, N' does not exist.');
        THROW 50310, @Message, 1;
    END;

    EXEC [$(SourceSystems)].[J1Sim].[usp_ReceiveAdmittedApplicant]
        @IdempotencyKey = @IdempotencyKey,
        @SourceApplicationId = @ApplicationId,
        @ActionCode = @ActionCode,
        @IdNumber = @TargetIdNumber,
        @FirstName = @FirstName,
        @MiddleName = @MiddleName,
        @LastName = @LastName,
        @BirthDate = @BirthDate,
        @Email = @Email,
        @Phone = @Phone,
        @AddressLine1 = @AddressLine1,
        @City = @City,
        @StateCode = @StateCode,
        @PostalCode = @PostalCode,
        @ProgramCode = @ProgramCode,
        @EntryTermCode = @EntryTermCode,
        @ResidencyCode = @ResidencyCode,
        @ResultIdNumber = @ResultIdNumber OUTPUT;
END;
