/*
tSQLt tests for the exception lifecycle (docs/specifications/integration-controls.md).
Tests that expect a procedure to fail run as NoTransaction tests because the procedures roll
back their own transactions; every table they touch is faked in SetUp.
*/
EXEC tSQLt.NewTestClass @ClassName = N'ExceptionTests';
GO

CREATE PROCEDURE [ExceptionTests].[SetUp]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[FakeAll];
END;
GO

CREATE PROCEDURE [ExceptionTests].[test an allowed transition records the previous and new status]
AS
BEGIN
    DECLARE @ExceptionId BIGINT;
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'INVALID_PROGRAM', @ExceptionId = @ExceptionId OUTPUT;

    EXEC [integration].[usp_TransitionException]
        @ExceptionId = @ExceptionId, @ToStatusCode = 'ASSIGNED', @ReasonText = N'Taking ownership',
        @AssignedTo = N'analyst.one', @Actor = N'analyst.one';

    SELECT ea.[FromStatusCode], ea.[ToStatusCode], ea.[ActionBy], ea.[ReasonText] INTO #Actual FROM [integration].[ExceptionAction] AS ea;
    SELECT TOP (0) a.[FromStatusCode], a.[ToStatusCode], a.[ActionBy], a.[ReasonText] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([FromStatusCode], [ToStatusCode], [ActionBy], [ReasonText])
    VALUES ('OPEN', 'ASSIGNED', N'analyst.one', N'Taking ownership');
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    DECLARE @AssignedTo NVARCHAR (128) = (SELECT e.[AssignedTo] FROM [integration].[IntegrationException] AS e);
    EXEC tSQLt.AssertEquals @Expected = N'analyst.one', @Actual = @AssignedTo;
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [ExceptionTests].[test a disallowed transition is rejected and changes nothing]
AS
BEGIN
    DECLARE @ExceptionId BIGINT;
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'INVALID_PROGRAM', @ExceptionId = @ExceptionId OUTPUT;

    DECLARE @ErrorNumber INT;
    BEGIN TRY
        EXEC [integration].[usp_TransitionException]
            @ExceptionId = @ExceptionId, @ToStatusCode = 'REPROCESSED', @ReasonText = N'Skipping ahead';
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
    END CATCH;

    DECLARE @Status VARCHAR (30) = (SELECT e.[ExceptionStatusCode] FROM [integration].[IntegrationException] AS e);
    DECLARE @Actions INT = (SELECT COUNT(*) FROM [integration].[ExceptionAction]);
    EXEC tSQLt.AssertEquals @Expected = 50102, @Actual = @ErrorNumber;
    EXEC tSQLt.AssertEquals @Expected = 'OPEN', @Actual = @Status;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Actions;
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [ExceptionTests].[test assigning requires the analyst it is assigned to]
AS
BEGIN
    DECLARE @ExceptionId BIGINT;
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'INVALID_PROGRAM', @ExceptionId = @ExceptionId OUTPUT;

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50103;
    EXEC [integration].[usp_TransitionException] @ExceptionId = @ExceptionId, @ToStatusCode = 'ASSIGNED', @ReasonText = N'Mine';
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [ExceptionTests].[test an identity exception cannot be resolved without an identity decision]
AS
BEGIN
    DECLARE @ExceptionId BIGINT;
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'AMBIGUOUS_MATCH', @ExceptionId = @ExceptionId OUTPUT;
    INSERT INTO [integration].[MatchDecision] (
        [ApplicationId], [SourceHash], [DecisionTypeCode], [RuleCode], [CandidateCount], [ConfidenceCategory],
        [DecidedBy], [DecidedAtUtc], [IsCurrent]
    )
    VALUES ('B0000000-0000-4000-8000-000000000001', 0x01, 'AMBIGUOUS', 'EMAIL_DOB', 2, 'HIGH', N'SYSTEM', SYSUTCDATETIME(), 1);

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50104;
    EXEC [integration].[usp_TransitionException] @ExceptionId = @ExceptionId, @ToStatusCode = 'RESOLVED', @ReasonText = N'Looks fine';
END;
GO

CREATE PROCEDURE [ExceptionTests].[test a recurring condition updates the existing exception once per batch]
AS
BEGIN
    DECLARE @Conditions [integration].[ExceptionCondition];
    INSERT INTO @Conditions ([ApplicationId], [ExceptionReasonCode], [IsPresent], [DetailCode], [SourceHash])
    VALUES ('B0000000-0000-4000-8000-000000000001', 'INVALID_PROGRAM', 1, 'INACTIVE', 0x01);

    EXEC [integration].[usp_RecordExceptionConditions] @BatchId = 100, @Conditions = @Conditions, @RaisedBy = N'test';
    EXEC [integration].[usp_RecordExceptionConditions] @BatchId = 100, @Conditions = @Conditions, @RaisedBy = N'test';
    EXEC [integration].[usp_RecordExceptionConditions] @BatchId = 101, @Conditions = @Conditions, @RaisedBy = N'test';

    SELECT e.[ExceptionStatusCode], e.[FirstSeenBatchId], e.[LastSeenBatchId], e.[OccurrenceCount]
    INTO #Actual
    FROM [integration].[IntegrationException] AS e;
    SELECT TOP (0) a.[ExceptionStatusCode], a.[FirstSeenBatchId], a.[LastSeenBatchId], a.[OccurrenceCount] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ExceptionStatusCode], [FirstSeenBatchId], [LastSeenBatchId], [OccurrenceCount]) VALUES ('OPEN', 100, 101, 2);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    DECLARE @Actions INT = (SELECT COUNT(*) FROM [integration].[ExceptionAction]);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Actions, @Message = N'only the creation is an action';
END;
GO

CREATE PROCEDURE [ExceptionTests].[test a condition that disappears resolves the exception and one that returns reopens it]
AS
BEGIN
    DECLARE @Present [integration].[ExceptionCondition];
    DECLARE @Absent [integration].[ExceptionCondition];
    INSERT INTO @Present ([ApplicationId], [ExceptionReasonCode], [IsPresent], [SourceHash])
    VALUES ('B0000000-0000-4000-8000-000000000001', 'INVALID_PROGRAM', 1, 0x01);
    INSERT INTO @Absent ([ApplicationId], [ExceptionReasonCode], [IsPresent], [SourceHash])
    VALUES ('B0000000-0000-4000-8000-000000000001', 'INVALID_PROGRAM', 0, 0x02);

    EXEC [integration].[usp_RecordExceptionConditions] @BatchId = 100, @Conditions = @Present, @RaisedBy = N'test';
    EXEC [integration].[usp_RecordExceptionConditions] @BatchId = 101, @Conditions = @Absent, @RaisedBy = N'test';
    DECLARE @AfterAbsent VARCHAR (30) = (SELECT e.[ExceptionStatusCode] FROM [integration].[IntegrationException] AS e);
    EXEC [integration].[usp_RecordExceptionConditions] @BatchId = 102, @Conditions = @Present, @RaisedBy = N'test';

    SELECT ea.[FromStatusCode], ea.[ToStatusCode], ea.[BatchId] INTO #Actual FROM [integration].[ExceptionAction] AS ea;
    SELECT TOP (0) a.[FromStatusCode], a.[ToStatusCode], a.[BatchId] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([FromStatusCode], [ToStatusCode], [BatchId])
    VALUES (NULL, 'OPEN', 100), ('OPEN', 'RESOLVED', 101), ('RESOLVED', 'OPEN', 102);

    EXEC tSQLt.AssertEquals @Expected = 'RESOLVED', @Actual = @AfterAbsent;
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ExceptionTests].[test an analyst closure holds the condition back until the source changes]
AS
BEGIN
    DECLARE @ExceptionId BIGINT;
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'INVALID_CONTACT_FORMAT',
        @SourceHash = 0x01, @ExceptionId = @ExceptionId OUTPUT;
    EXEC [integration].[usp_TransitionException]
        @ExceptionId = @ExceptionId, @ToStatusCode = 'CLOSED', @ReasonText = N'Applicant has no other email';

    DECLARE @SameVersion [integration].[ExceptionCondition];
    DECLARE @NewVersion [integration].[ExceptionCondition];
    INSERT INTO @SameVersion ([ApplicationId], [ExceptionReasonCode], [IsPresent], [SourceHash])
    VALUES ('B0000000-0000-4000-8000-000000000001', 'INVALID_CONTACT_FORMAT', 1, 0x01);
    INSERT INTO @NewVersion ([ApplicationId], [ExceptionReasonCode], [IsPresent], [SourceHash])
    VALUES ('B0000000-0000-4000-8000-000000000001', 'INVALID_CONTACT_FORMAT', 1, 0x02);

    EXEC [integration].[usp_RecordExceptionConditions] @BatchId = 100, @Conditions = @SameVersion, @RaisedBy = N'test';
    DECLARE @AfterSameVersion INT = (SELECT COUNT(*) FROM [integration].[IntegrationException]);
    EXEC [integration].[usp_RecordExceptionConditions] @BatchId = 101, @Conditions = @NewVersion, @RaisedBy = N'test';
    DECLARE @AfterNewVersion INT = (SELECT COUNT(*) FROM [integration].[IntegrationException]);

    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @AfterSameVersion, @Message = N'not re-raised for the closed version';
    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @AfterNewVersion, @Message = N'raised again after a source change';
END;
GO

CREATE PROCEDURE [ExceptionTests].[test exceptions of an application that is no longer eligible are closed]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001';
    UPDATE a SET a.[IsEligible] = 0, a.[ApplicationStatus] = 'WITHDRAWN' FROM [staging].[Applicant] AS a;
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'INVALID_PROGRAM';

    EXEC [integration].[usp_RaiseValidationExceptions] @BatchId = 100;

    SELECT e.[ExceptionStatusCode], e.[SourceHash] INTO #Actual FROM [integration].[IntegrationException] AS e;
    SELECT TOP (0) a.[ExceptionStatusCode], a.[SourceHash] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ExceptionStatusCode], [SourceHash]) VALUES ('CLOSED', NULL);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ExceptionTests].[test resolving an ambiguous match records a manual decision and resolves the exception]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000011, @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000012, @FirstName = N'ROWAN', @Email = N'okafor.family@example.com';
    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;
    DECLARE @ExceptionId BIGINT = (SELECT e.[ExceptionId] FROM [integration].[IntegrationException] AS e);

    EXEC [integration].[usp_ResolveExceptionMatch]
        @ExceptionId = @ExceptionId, @MatchedIdNumber = 9000011, @Note = N'Confirmed with Admissions', @Actor = N'registrar.one';

    SELECT d.[DecisionTypeCode], d.[MatchedIdNumber], d.[DecidedBy], d.[ConfidenceCategory]
    INTO #Actual
    FROM [integration].[MatchDecision] AS d
    WHERE d.[IsCurrent] = 1;
    SELECT TOP (0) a.[DecisionTypeCode], a.[MatchedIdNumber], a.[DecidedBy], a.[ConfidenceCategory] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([DecisionTypeCode], [MatchedIdNumber], [DecidedBy], [ConfidenceCategory])
    VALUES ('MANUAL_MATCH', 9000011, N'registrar.one', 'MANUAL');
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    DECLARE @Status VARCHAR (30) = (SELECT e.[ExceptionStatusCode] FROM [integration].[IntegrationException] AS e);
    EXEC tSQLt.AssertEquals @Expected = 'RESOLVED', @Actual = @Status;

    -- The next MATCH run must keep the analyst's decision and leave the exception resolved.
    EXEC [integration].[usp_RunMatchStep] @BatchId = 101;
    DECLARE @CurrentType VARCHAR (20) = (SELECT d.[DecisionTypeCode] FROM [integration].[MatchDecision] AS d WHERE d.[IsCurrent] = 1);
    SET @Status = (SELECT e.[ExceptionStatusCode] FROM [integration].[IntegrationException] AS e);
    EXEC tSQLt.AssertEquals @Expected = 'MANUAL_MATCH', @Actual = @CurrentType;
    EXEC tSQLt.AssertEquals @Expected = 'RESOLVED', @Actual = @Status;
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [ExceptionTests].[test resolving an ambiguous match with a person who is not a candidate is rejected]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000011, @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000012, @FirstName = N'ROWAN', @Email = N'okafor.family@example.com';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @FirstName = N'SOMEONE', @BirthDate = '1990-01-01';
    EXEC [integration].[usp_RunMatchStep] @BatchId = 100;
    DECLARE @ExceptionId BIGINT = (SELECT e.[ExceptionId] FROM [integration].[IntegrationException] AS e);

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50115;
    EXEC [integration].[usp_ResolveExceptionMatch] @ExceptionId = @ExceptionId, @MatchedIdNumber = 2400100;
END;
GO

CREATE PROCEDURE [ExceptionTests].[test the database refuses to record a transition that is not allowed]
AS
BEGIN
    EXEC tSQLt.ApplyConstraint @TableName = N'integration.ExceptionAction', @ConstraintName = N'FK_integration_ExceptionAction_Transition';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 547;

    INSERT INTO [integration].[ExceptionAction] (
        [ExceptionId], [FromStatusCode], [ToStatusCode], [ActionBy], [ActionAtUtc], [ReasonText]
    )
    VALUES (1, 'OPEN', 'REPROCESSED', N'someone', SYSUTCDATETIME(), N'bypassing the procedure');
END;
GO
