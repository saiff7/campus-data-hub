/*
tSQLt tests for staging.usp_StageSlateApplicants. Landing and reference tables are faked so
each test controls the governed terms and programs it depends on.
*/
EXEC tSQLt.NewTestClass @ClassName = N'StagingTests';
GO

CREATE PROCEDURE [StagingTests].[SetUp]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'landing.SlateApplicantRaw', @Identity = 1;
    EXEC tSQLt.FakeTable @TableName = N'landing.SlateApplicationRaw', @Identity = 1;
    EXEC tSQLt.FakeTable @TableName = N'staging.Applicant';
    EXEC tSQLt.FakeTable @TableName = N'reference.AcademicTerm';
    EXEC tSQLt.FakeTable @TableName = N'reference.ProgramCrosswalk';

    INSERT INTO [reference].[AcademicTerm] ([TermCode], [IsOpenForAdmission])
    VALUES ('2027FA', 1), ('2026FA', 0);
    INSERT INTO [reference].[ProgramCrosswalk] ([SlateProgramCode], [J1ProgramCode], [IsActive])
    VALUES ('ADM-CIS', 'CIS.AS', 1), ('ADM-MEDA', 'MEDA.CERT', 0);
END;
GO

CREATE PROCEDURE [StagingTests].[AddLandedApplication]
    @ApplicationId UNIQUEIDENTIFIER,
    @PersonId      UNIQUEIDENTIFIER,
    @Status        VARCHAR (20)   = 'ADMITTED',
    @Exported      BIT            = 1,
    @TermCode      VARCHAR (10)   = '2027FA',
    @ProgramCode   VARCHAR (20)   = 'ADM-CIS',
    @FirstName     NVARCHAR (100) = N'Riley',
    @Email         NVARCHAR (320) = N'riley@example.com',
    @StateCode     CHAR (2)       = 'MA',
    @CountryCode   CHAR (2)       = 'US',
    @BatchId       BIGINT         = 1
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [landing].[SlateApplicantRaw] AS r WHERE r.[PersonId] = @PersonId)
        INSERT INTO [landing].[SlateApplicantRaw] (
            [BatchId], [PersonId], [FirstName], [LastName], [BirthDate], [Email], [StateCode], [CountryCode],
            [PostalCode], [RecordHash]
        )
        VALUES (
            @BatchId, @PersonId, @FirstName, N'Okafor', '2004-03-15', @Email, @StateCode, @CountryCode,
            '01103', HASHBYTES('SHA2_256', CONCAT(@PersonId, @FirstName, @Email))
        );

    INSERT INTO [landing].[SlateApplicationRaw] (
        [BatchId], [ApplicationId], [PersonId], [EntryTermCode], [StudentType], [ApplicationStatus],
        [ProgramChoice1], [ExportQueuedAtUtc], [RecordHash]
    )
    VALUES (
        @BatchId, @ApplicationId, @PersonId, @TermCode, 'FIRST_TIME', @Status, @ProgramCode,
        CASE WHEN @Exported = 1 THEN CAST('2026-06-01T00:00:00' AS DATETIME2 (3)) END,
        HASHBYTES('SHA2_256', CONCAT(@ApplicationId, @Status, @TermCode, @ProgramCode))
    );
END;
GO

CREATE PROCEDURE [StagingTests].[test raw values are kept beside standardized values]
AS
BEGIN
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001',
        @PersonId = 'A0000000-0000-4000-8000-000000000001',
        @FirstName = N'  riley ',
        @Email = N' Riley@Example.COM';

    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 10;

    SELECT a.[FirstNameRaw], a.[FirstNameStd], a.[EmailRaw], a.[EmailStd], a.[IsEmailValid]
    INTO #Actual
    FROM [staging].[Applicant] AS a;

    SELECT TOP (0) a.[FirstNameRaw], a.[FirstNameStd], a.[EmailRaw], a.[EmailStd], a.[IsEmailValid]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected ([FirstNameRaw], [FirstNameStd], [EmailRaw], [EmailStd], [IsEmailValid])
    VALUES (N'  riley ', N'RILEY', N' Riley@Example.COM', N'riley@example.com', 1);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [StagingTests].[test a malformed email is flagged invalid and not standardized]
AS
BEGIN
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001',
        @PersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'casey.rivera@@example.com';

    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 10;

    SELECT a.[EmailRaw], a.[EmailStd], a.[IsEmailValid] INTO #Actual FROM [staging].[Applicant] AS a;
    SELECT TOP (0) a.[EmailRaw], a.[EmailStd], a.[IsEmailValid] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([EmailRaw], [EmailStd], [IsEmailValid]) VALUES (N'casey.rivera@@example.com', NULL, 0);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [StagingTests].[test only exported admitted or deposited applications are eligible]
AS
BEGIN
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @PersonId = 'A0000000-0000-4000-8000-000000000001',
        @Status = 'ADMITTED';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @PersonId = 'A0000000-0000-4000-8000-000000000002',
        @Status = 'DEPOSITED';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000003', @PersonId = 'A0000000-0000-4000-8000-000000000003',
        @Status = 'ADMITTED', @Exported = 0;
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000004', @PersonId = 'A0000000-0000-4000-8000-000000000004',
        @Status = 'DENIED';

    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 10;

    SELECT a.[ApplicationId], a.[IsEligible] INTO #Actual FROM [staging].[Applicant] AS a;
    SELECT TOP (0) a.[ApplicationId], a.[IsEligible] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ApplicationId], [IsEligible])
    VALUES
        ('B0000000-0000-4000-8000-000000000001', 1),
        ('B0000000-0000-4000-8000-000000000002', 1),
        ('B0000000-0000-4000-8000-000000000003', 0),
        ('B0000000-0000-4000-8000-000000000004', 0);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [StagingTests].[test term and program validation codes]
AS
BEGIN
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @PersonId = 'A0000000-0000-4000-8000-000000000001';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @PersonId = 'A0000000-0000-4000-8000-000000000002',
        @TermCode = '2031FA', @ProgramCode = 'ADM-NOPE';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000003', @PersonId = 'A0000000-0000-4000-8000-000000000003',
        @TermCode = '2026FA', @ProgramCode = 'ADM-MEDA';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000004', @PersonId = 'A0000000-0000-4000-8000-000000000004',
        @TermCode = NULL, @ProgramCode = NULL;

    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 10;

    SELECT
        a.[ApplicationId], a.[EntryTermCode], a.[TermValidationCode], a.[J1ProgramCode], a.[ProgramValidationCode],
        a.[MissingRequiredFields]
    INTO #Actual
    FROM [staging].[Applicant] AS a;

    SELECT TOP (0)
        a.[ApplicationId], a.[EntryTermCode], a.[TermValidationCode], a.[J1ProgramCode], a.[ProgramValidationCode],
        a.[MissingRequiredFields]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected (
        [ApplicationId], [EntryTermCode], [TermValidationCode], [J1ProgramCode], [ProgramValidationCode], [MissingRequiredFields]
    )
    VALUES
        ('B0000000-0000-4000-8000-000000000001', '2027FA', NULL, 'CIS.AS', NULL, NULL),
        ('B0000000-0000-4000-8000-000000000002', NULL, 'UNKNOWN_TERM', NULL, 'NOT_IN_CROSSWALK', NULL),
        ('B0000000-0000-4000-8000-000000000003', NULL, 'CLOSED_TERM', NULL, 'INACTIVE', NULL),
        ('B0000000-0000-4000-8000-000000000004', NULL, 'MISSING', NULL, 'MISSING', 'ENTRY_TERM,PROGRAM');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [StagingTests].[test eligible applications for the same person and term are counted as duplicates]
AS
BEGIN
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @PersonId = 'A0000000-0000-4000-8000-000000000001';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @PersonId = 'A0000000-0000-4000-8000-000000000001';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000003', @PersonId = 'A0000000-0000-4000-8000-000000000001',
        @Status = 'WITHDRAWN';

    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 10;

    SELECT a.[ApplicationId], a.[DuplicateApplicationCount] INTO #Actual FROM [staging].[Applicant] AS a;
    SELECT TOP (0) a.[ApplicationId], a.[DuplicateApplicationCount] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ApplicationId], [DuplicateApplicationCount])
    VALUES
        ('B0000000-0000-4000-8000-000000000001', 2),
        ('B0000000-0000-4000-8000-000000000002', 2),
        ('B0000000-0000-4000-8000-000000000003', 1);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [StagingTests].[test residency is derived from the primary address]
AS
BEGIN
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @PersonId = 'A0000000-0000-4000-8000-000000000001',
        @StateCode = 'MA';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @PersonId = 'A0000000-0000-4000-8000-000000000002',
        @StateCode = 'NH';
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000003', @PersonId = 'A0000000-0000-4000-8000-000000000003',
        @StateCode = NULL, @CountryCode = 'CA';

    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 10;

    SELECT a.[ApplicationId], a.[ResidencyCode] INTO #Actual FROM [staging].[Applicant] AS a;
    SELECT TOP (0) a.[ApplicationId], a.[ResidencyCode] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ApplicationId], [ResidencyCode])
    VALUES
        ('B0000000-0000-4000-8000-000000000001', 'IN_STATE'),
        ('B0000000-0000-4000-8000-000000000002', 'OUT_OF_STATE'),
        ('B0000000-0000-4000-8000-000000000003', 'INTERNATIONAL');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [StagingTests].[test restaging unchanged data writes nothing]
AS
BEGIN
    EXEC [StagingTests].[AddLandedApplication]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @PersonId = 'A0000000-0000-4000-8000-000000000001';

    DECLARE @FirstRun INT;
    DECLARE @SecondRun INT;
    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 10, @RowsAffected = @FirstRun OUTPUT;
    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 11, @RowsAffected = @SecondRun OUTPUT;

    DECLARE @LastStagedBatchId BIGINT = (SELECT a.[LastStagedBatchId] FROM [staging].[Applicant] AS a);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @FirstRun;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @SecondRun;
    EXEC tSQLt.AssertEquals @Expected = 10, @Actual = @LastStagedBatchId;
END;
GO

-- Error paths run outside tSQLt's transaction because the procedure rolls back on error.
--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [StagingTests].[test an application without a landed applicant fails loudly]
AS
BEGIN
    INSERT INTO [landing].[SlateApplicationRaw] (
        [BatchId], [ApplicationId], [PersonId], [StudentType], [ApplicationStatus], [RecordHash]
    )
    VALUES (
        1, 'B0000000-0000-4000-8000-000000000001', 'A0000000-0000-4000-8000-000000000009', 'FIRST_TIME', 'ADMITTED',
        HASHBYTES('SHA2_256', N'orphan')
    );

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50040;
    EXEC [staging].[usp_StageSlateApplicants] @BatchId = 10;
END;
GO

CREATE PROCEDURE [StagingTests].[test credentials stage the latest landed version once]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'landing.J1CredentialRaw', @Identity = 1;
    EXEC tSQLt.FakeTable @TableName = N'staging.CredentialAwarded';

    INSERT INTO [landing].[J1CredentialRaw] ([BatchId], [CredentialAwardedId], [IdNumber], [ProgramCode], [TermCode], [AwardedDate])
    VALUES
        (1, 501, 2400001, 'WELD.CERT', '2025SP', '2025-05-20'),
        (2, 501, 2400001, 'WELD.CERT', '2025SP', '2025-05-22'),
        (1, 502, 2400002, 'NURS.AS', '2026SP', '2026-05-21');

    DECLARE @FirstRun INT;
    DECLARE @SecondRun INT;
    EXEC [staging].[usp_StageJ1Credentials] @BatchId = 10, @RowsAffected = @FirstRun OUTPUT;
    EXEC [staging].[usp_StageJ1Credentials] @BatchId = 11, @RowsAffected = @SecondRun OUTPUT;

    SELECT c.[CredentialAwardedId], c.[AwardedDate], c.[LastStagedBatchId] INTO #Actual FROM [staging].[CredentialAwarded] AS c;
    SELECT TOP (0) a.* INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([CredentialAwardedId], [AwardedDate], [LastStagedBatchId])
    VALUES (501, '2025-05-22', 10), (502, '2026-05-21', 10);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @FirstRun;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @SecondRun;
END;
GO
