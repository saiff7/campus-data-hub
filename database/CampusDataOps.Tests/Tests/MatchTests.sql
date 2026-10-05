/*
tSQLt tests for the match hierarchy and decision table (docs/specifications/matching-rules.md,
ADR-001). Each test builds the smallest staged data that exercises one row of the table.
*/
EXEC tSQLt.NewTestClass @ClassName = N'MatchTests';
GO

CREATE PROCEDURE [MatchTests].[SetUp]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[FakeAll];
END;
GO

CREATE PROCEDURE [MatchTests].[AssertCurrentDecision]
    @ApplicationId    UNIQUEIDENTIFIER,
    @DecisionTypeCode VARCHAR (20),
    @RuleCode         VARCHAR (20),
    @MatchedIdNumber  INT,
    @ConflictCode     VARCHAR (40) = NULL
AS
BEGIN
    SELECT d.[DecisionTypeCode], d.[RuleCode], d.[MatchedIdNumber], d.[ConflictCode]
    INTO #Actual
    FROM [integration].[MatchDecision] AS d
    WHERE d.[ApplicationId] = @ApplicationId AND d.[IsCurrent] = 1;

    SELECT TOP (0) a.[DecisionTypeCode], a.[RuleCode], a.[MatchedIdNumber], a.[ConflictCode] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([DecisionTypeCode], [RuleCode], [MatchedIdNumber], [ConflictCode])
    VALUES (@DecisionTypeCode, @RuleCode, @MatchedIdNumber, @ConflictCode);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [MatchTests].[test an existing crosswalk auto-matches]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @FirstName = N'SOMEONE', @BirthDate = '1990-01-01';
    INSERT INTO [integration].[SourceCrosswalk] ([SourceSystemCode], [SourceRecordId], [TargetIdNumber])
    VALUES ('SLATE_SIM', 'A0000000-0000-4000-8000-000000000001', 2400100);

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'AUTO_MATCH',
        @RuleCode = 'CROSSWALK', @MatchedIdNumber = 2400100;
END;
GO

CREATE PROCEDURE [MatchTests].[test a unique SIS ID claim auto-matches with exact confidence]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @SisIdClaimRaw = '2400100';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100;

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'AUTO_MATCH',
        @RuleCode = 'SIS_ID', @MatchedIdNumber = 2400100;
    DECLARE @Confidence VARCHAR (10) = (SELECT d.[ConfidenceCategory] FROM [integration].[MatchDecision] AS d);
    EXEC tSQLt.AssertEquals @Expected = 'EXACT', @Actual = @Confidence;
END;
GO

CREATE PROCEDURE [MatchTests].[test a unique email and birth date auto-matches with high confidence]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'riley@example.com', @PostalCode5 = '99999';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @Email = N'riley@example.com';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'AUTO_MATCH',
        @RuleCode = 'EMAIL_DOB', @MatchedIdNumber = 2400100;
    DECLARE @Confidence VARCHAR (10) = (SELECT d.[ConfidenceCategory] FROM [integration].[MatchDecision] AS d);
    EXEC tSQLt.AssertEquals @Expected = 'HIGH', @Actual = @Confidence;
END;
GO

-- The twins case from the edge-case fixtures: a shared family email and birth date.
CREATE PROCEDURE [MatchTests].[test two email and birth date candidates create an ambiguous match and never auto-merge]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000011, @FirstName = N'RILEY', @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000012, @FirstName = N'ROWAN', @Email = N'okafor.family@example.com';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'AMBIGUOUS',
        @RuleCode = 'EMAIL_DOB', @MatchedIdNumber = NULL;

    DECLARE @Exceptions INT = (
        SELECT COUNT(*) FROM [integration].[IntegrationException] AS e
        WHERE e.[ExceptionReasonCode] = 'AMBIGUOUS_MATCH' AND e.[ExceptionStatusCode] = 'OPEN'
    );
    DECLARE @Candidates INT = (SELECT COUNT(*) FROM [integration].[MatchCandidate] AS mc WHERE mc.[RuleCode] = 'EMAIL_DOB');
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Exceptions;
    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @Candidates, @Message = N'both candidates are stored as evidence';
END;
GO

CREATE PROCEDURE [MatchTests].[test name, birth date and postal code alone is review only]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'riley.new@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @Email = N'riley.old@example.com';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'REVIEW_REQUIRED',
        @RuleCode = 'NAME_DOB_POSTAL', @MatchedIdNumber = NULL;
    DECLARE @Exceptions INT = (
        SELECT COUNT(*) FROM [integration].[IntegrationException] AS e WHERE e.[ExceptionReasonCode] = 'POSSIBLE_MATCH_REVIEW'
    );
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Exceptions;
END;
GO

CREATE PROCEDURE [MatchTests].[test no candidate becomes a new person]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'new@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @FirstName = N'SOMEONE', @BirthDate = '1990-01-01';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'NEW_PERSON',
        @RuleCode = NULL, @MatchedIdNumber = NULL;
    DECLARE @Exceptions INT = (SELECT COUNT(*) FROM [integration].[IntegrationException]);
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Exceptions;
END;
GO

CREATE PROCEDURE [MatchTests].[test a SIS ID whose person has a different birth date is an identity conflict]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @SisIdClaimRaw = '2400100';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @BirthDate = '1980-07-07';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'IDENTITY_CONFLICT',
        @RuleCode = NULL, @MatchedIdNumber = NULL, @ConflictCode = 'SIS_ID_BIRTH_DATE_MISMATCH';
    DECLARE @Exceptions INT = (
        SELECT COUNT(*) FROM [integration].[IntegrationException] AS e WHERE e.[ExceptionReasonCode] = 'IDENTITY_CONFLICT'
    );
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Exceptions;
END;
GO

CREATE PROCEDURE [MatchTests].[test a SIS ID claimed by two Slate-Sim people is an identity conflict]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @SisIdClaimRaw = '2400100';
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @SlatePersonId = 'A0000000-0000-4000-8000-000000000002',
        @FirstName = N'CASEY', @SisIdClaimRaw = '2400100';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100;

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'IDENTITY_CONFLICT',
        @RuleCode = NULL, @MatchedIdNumber = NULL, @ConflictCode = 'SIS_ID_CLAIMED_BY_MULTIPLE';
    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @DecisionTypeCode = 'IDENTITY_CONFLICT',
        @RuleCode = NULL, @MatchedIdNumber = NULL, @ConflictCode = 'SIS_ID_CLAIMED_BY_MULTIPLE';
END;
GO

CREATE PROCEDURE [MatchTests].[test an unknown or malformed SIS ID is an identity conflict]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @SisIdClaimRaw = '2499999';
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @SlatePersonId = 'A0000000-0000-4000-8000-000000000002',
        @FirstName = N'CASEY', @SisIdClaimRaw = 'S-24001';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'IDENTITY_CONFLICT',
        @RuleCode = NULL, @MatchedIdNumber = NULL, @ConflictCode = 'SIS_ID_NOT_FOUND';
    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @DecisionTypeCode = 'IDENTITY_CONFLICT',
        @RuleCode = NULL, @MatchedIdNumber = NULL, @ConflictCode = 'SIS_ID_INVALID_FORMAT';
END;
GO

CREATE PROCEDURE [MatchTests].[test rules that point to different people are an identity conflict]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @SisIdClaimRaw = '2400100', @Email = N'riley@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @Email = N'other@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400200, @FirstName = N'ROWAN', @Email = N'riley@example.com';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'IDENTITY_CONFLICT',
        @RuleCode = NULL, @MatchedIdNumber = NULL, @ConflictCode = 'RULES_DISAGREE';
END;
GO

CREATE PROCEDURE [MatchTests].[test a lower ambiguous rule that includes the decided person does not block]
AS
BEGIN
    -- The SIS ID names one twin exactly; email + birth date finds both twins, including that one.
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @SisIdClaimRaw = '9000011', @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000011, @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000012, @FirstName = N'ROWAN', @Email = N'okafor.family@example.com';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    EXEC [MatchTests].[AssertCurrentDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'AUTO_MATCH',
        @RuleCode = 'SIS_ID', @MatchedIdNumber = 9000011;
END;
GO

CREATE PROCEDURE [MatchTests].[test a rerun with unchanged data writes no new decision, evaluation or exception]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'riley@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @Email = N'riley@example.com';

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;
    EXEC [integration].[usp_RunMatchStep] @BatchId = 101;

    DECLARE @Decisions INT = (SELECT COUNT(*) FROM [integration].[MatchDecision]);
    DECLARE @Evaluations INT = (SELECT COUNT(*) FROM [integration].[MatchEvaluation]);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Decisions;
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Evaluations, @Message = N'an auto-matched application is not re-evaluated';
END;
GO

CREATE PROCEDURE [MatchTests].[test a changed source version supersedes the current decision]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'new@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @FirstName = N'SOMEONE', @Email = N'riley@example.com';
    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    UPDATE a SET a.[EmailStd] = N'riley@example.com', a.[FirstNameStd] = N'SOMEONE', a.[SourceHash] = 0x02
    FROM [staging].[Applicant] AS a;
    EXEC [integration].[usp_RunMatchStep] @BatchId = 101;

    SELECT d.[DecisionTypeCode], d.[IsCurrent], d.[BatchId] INTO #Actual FROM [integration].[MatchDecision] AS d;
    SELECT TOP (0) a.[DecisionTypeCode], a.[IsCurrent], a.[BatchId] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([DecisionTypeCode], [IsCurrent], [BatchId]) VALUES ('NEW_PERSON', 0, 100), ('AUTO_MATCH', 1, 101);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [MatchTests].[test an application blocked by a validation exception is not matched]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001';
    UPDATE a SET a.[J1ProgramCode] = NULL, a.[ProgramValidationCode] = 'INACTIVE' FROM [staging].[Applicant] AS a;

    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;

    DECLARE @Decisions INT = (SELECT COUNT(*) FROM [integration].[MatchDecision]);
    DECLARE @Exceptions INT = (
        SELECT COUNT(*) FROM [integration].[IntegrationException] AS e WHERE e.[ExceptionReasonCode] = 'INVALID_PROGRAM'
    );
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Decisions;
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Exceptions;
END;
GO

CREATE PROCEDURE [MatchTests].[test the database rejects an automatic match with more than one candidate]
AS
BEGIN
    EXEC tSQLt.ApplyConstraint
        @TableName = N'integration.MatchDecision', @ConstraintName = N'CK_integration_MatchDecision_AutoMatchIsUniqueAndAutomatic';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 547;

    INSERT INTO [integration].[MatchDecision] (
        [ApplicationId], [SourceHash], [DecisionTypeCode], [RuleCode], [CandidateCount], [MatchedIdNumber],
        [ConfidenceCategory], [DecidedBy], [DecidedAtUtc], [IsCurrent]
    )
    VALUES (
        'B0000000-0000-4000-8000-000000000001', 0x01, 'AUTO_MATCH', 'EMAIL_DOB', 2, 9000011,
        'HIGH', N'SYSTEM', SYSUTCDATETIME(), 1
    );
END;
GO

CREATE PROCEDURE [MatchTests].[test the database rejects an automatic match from the review-only rule]
AS
BEGIN
    EXEC tSQLt.ApplyConstraint
        @TableName = N'integration.MatchDecision', @ConstraintName = N'CK_integration_MatchDecision_AutoMatchIsUniqueAndAutomatic';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 547;

    INSERT INTO [integration].[MatchDecision] (
        [ApplicationId], [SourceHash], [DecisionTypeCode], [RuleCode], [CandidateCount], [MatchedIdNumber],
        [ConfidenceCategory], [DecidedBy], [DecidedAtUtc], [IsCurrent]
    )
    VALUES (
        'B0000000-0000-4000-8000-000000000001', 0x01, 'AUTO_MATCH', 'NAME_DOB_POSTAL', 1, 2400100,
        'REVIEW', N'SYSTEM', SYSUTCDATETIME(), 1
    );
END;
GO
