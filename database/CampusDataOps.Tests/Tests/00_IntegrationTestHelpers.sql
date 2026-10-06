/*
Shared helpers for the integration test classes. This class holds no tests. FakeAll replaces
every table the integration procedures write or read (except governed reference codes, which
are part of the specification under test) so tests are isolated and safe to run as
NoTransaction tests.
*/
EXEC tSQLt.NewTestClass @ClassName = N'IntegrationTestHelpers';
GO

CREATE PROCEDURE [IntegrationTestHelpers].[FakeAll]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'staging.Applicant';
    EXEC tSQLt.FakeTable @TableName = N'staging.Person';
    EXEC tSQLt.FakeTable @TableName = N'integration.SourceCrosswalk', @Identity = 1;
    EXEC tSQLt.FakeTable @TableName = N'integration.MatchEvaluation', @Identity = 1, @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'integration.MatchCandidate';
    EXEC tSQLt.FakeTable @TableName = N'integration.MatchDecision', @Identity = 1, @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'integration.IntegrationException', @Identity = 1, @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'integration.ExceptionAction', @Identity = 1, @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'integration.OutboundStudentQueue', @Identity = 1, @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'audit.ErrorLog', @Identity = 1, @Defaults = 1;
END;
GO

-- An eligible, valid staged application. Every matching attribute is a parameter.
CREATE PROCEDURE [IntegrationTestHelpers].[AddApplicant]
    @ApplicationId UNIQUEIDENTIFIER,
    @SlatePersonId UNIQUEIDENTIFIER,
    @FirstName     NVARCHAR (100) = N'RILEY',
    @LastName      NVARCHAR (100) = N'OKAFOR',
    @BirthDate     DATE           = '2004-03-15',
    @Email         NVARCHAR (320) = NULL,
    @PostalCode5   CHAR (5)       = '01103',
    @SisIdClaimRaw VARCHAR (50)   = NULL,
    @SourceHash    BINARY (32)    = 0x01
AS
BEGIN
    INSERT INTO [staging].[Applicant] (
        [ApplicationId], [SlatePersonId], [SourceHash], [ApplicationStatus], [IsEligible], [ExportQueuedAtUtc],
        [FirstNameRaw], [FirstNameStd], [LastNameRaw], [LastNameStd], [BirthDate], [EmailRaw], [EmailStd], [IsEmailValid],
        [PostalCode5], [ResidencyCode], [SisIdClaimRaw], [SisIdClaim], [IsSisIdClaimValid], [EntryTermCodeRaw],
        [EntryTermCode], [ProgramChoice1Raw], [J1ProgramCode], [DuplicateApplicationCount]
    )
    VALUES (
        @ApplicationId, @SlatePersonId, @SourceHash, 'ADMITTED', 1, '2026-06-01T00:00:00',
        @FirstName, @FirstName, @LastName, @LastName, @BirthDate, @Email, @Email,
        CASE WHEN @Email IS NOT NULL THEN 1 END,
        @PostalCode5, 'IN_STATE', @SisIdClaimRaw,
        CASE WHEN @SisIdClaimRaw LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN CAST(@SisIdClaimRaw AS INT) END,
        CASE WHEN @SisIdClaimRaw IS NULL THEN NULL WHEN @SisIdClaimRaw LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN 1 ELSE 0 END,
        '2027FA', '2027FA', 'ADM-CIS', 'CIS.AS', 1
    );
END;
GO

CREATE PROCEDURE [IntegrationTestHelpers].[AddPerson]
    @IdNumber      INT,
    @FirstName     NVARCHAR (100) = N'RILEY',
    @LastName      NVARCHAR (100) = N'OKAFOR',
    @BirthDate     DATE           = '2004-03-15',
    @Email         NVARCHAR (320) = NULL,
    @PostalCode5   CHAR (5)       = '01103',
    @StudentStatus VARCHAR (20)   = NULL
AS
BEGIN
    INSERT INTO [staging].[Person] (
        [IdNumber], [FirstNameRaw], [FirstNameStd], [LastNameRaw], [LastNameStd], [BirthDate], [EmailRaw], [EmailStd],
        [PostalCode5], [HasStudentRecord], [StudentStatus], [StudentProgramCode]
    )
    VALUES (
        @IdNumber, @FirstName, @FirstName, @LastName, @LastName, @BirthDate, @Email, @Email,
        @PostalCode5, CASE WHEN @StudentStatus IS NULL THEN 0 ELSE 1 END, @StudentStatus,
        CASE WHEN @StudentStatus IS NOT NULL THEN 'BUS.AS' END
    );
END;
GO

CREATE PROCEDURE [IntegrationTestHelpers].[AddException]
    @ApplicationId UNIQUEIDENTIFIER,
    @ReasonCode    VARCHAR (40),
    @StatusCode    VARCHAR (30) = 'OPEN',
    @SourceHash    BINARY (32)  = 0x01,
    @ExceptionId   BIGINT       = NULL OUTPUT
AS
BEGIN
    INSERT INTO [integration].[IntegrationException] (
        [ExceptionReasonCode], [SourceSystemCode], [ApplicationId], [ExceptionStatusCode], [Severity], [SourceHash],
        [FirstSeenBatchId], [LastSeenBatchId], [OccurrenceCount]
    )
    VALUES (@ReasonCode, 'SLATE_SIM', @ApplicationId, @StatusCode, 'HIGH', @SourceHash, 1, 1, 1);

    SET @ExceptionId = CAST(SCOPE_IDENTITY() AS BIGINT);
END;
GO

CREATE PROCEDURE [IntegrationTestHelpers].[AddDecision]
    @ApplicationId    UNIQUEIDENTIFIER,
    @DecisionTypeCode VARCHAR (20) = 'NEW_PERSON',
    @MatchedIdNumber  INT          = NULL,
    @SourceHash       BINARY (32)  = 0x01
AS
BEGIN
    INSERT INTO [integration].[MatchDecision] (
        [ApplicationId], [SourceHash], [DecisionTypeCode], [RuleCode], [CandidateCount], [MatchedIdNumber],
        [ConfidenceCategory], [DecidedBy], [DecidedAtUtc], [IsCurrent]
    )
    VALUES (
        @ApplicationId, @SourceHash, @DecisionTypeCode,
        CASE WHEN @DecisionTypeCode = 'AUTO_MATCH' THEN 'EMAIL_DOB' END,
        CASE WHEN @MatchedIdNumber IS NULL THEN 0 ELSE 1 END,
        @MatchedIdNumber, 'HIGH', N'SYSTEM', SYSUTCDATETIME(), 1
    );
END;
GO
