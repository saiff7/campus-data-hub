/*
tSQLt tests for reconciliation (docs/specifications/integration-controls.md). The J1-Sim target
view is faked; SetFakeViewOn lets test procedures that insert into it compile.
*/
EXEC tSQLt.NewTestClass @ClassName = N'ReconciliationTests';
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'integration';
GO

EXEC tSQLt.SetFakeViewOn @SchemaName = N'integration';
GO

CREATE PROCEDURE [ReconciliationTests].[SetUp]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[FakeAll];
    EXEC tSQLt.FakeTable @TableName = N'integration.vw_J1TargetStudent';
    EXEC tSQLt.FakeTable @TableName = N'integration.ReconciliationDetail';
    EXEC tSQLt.FakeTable @TableName = N'integration.ReconciliationResult', @ComputedColumns = 1;
    EXEC tSQLt.FakeTable @TableName = N'integration.ReconciliationEntityCount', @ComputedColumns = 1;
    EXEC tSQLt.FakeTable @TableName = N'landing.SlateApplicationRaw';
    EXEC tSQLt.FakeTable @TableName = N'landing.J1PersonRaw';
    EXEC tSQLt.FakeTable @TableName = N'landing.J1EnrollmentRaw';
    EXEC tSQLt.FakeTable @TableName = N'landing.J1FinancialAidRaw';
    EXEC tSQLt.FakeTable @TableName = N'landing.J1AccountTransactionRaw';
    EXEC tSQLt.FakeTable @TableName = N'landing.DirectoryAccountRaw';
    EXEC tSQLt.FakeTable @TableName = N'staging.Enrollment';
    EXEC tSQLt.FakeTable @TableName = N'staging.FinancialAidAward';
    EXEC tSQLt.FakeTable @TableName = N'staging.AccountTransaction';
    EXEC tSQLt.FakeTable @TableName = N'staging.DirectoryAccount';
END;
GO

-- A written application: a SUCCEEDED queue row and, when confirmed, the matching J1-Sim state.
CREATE PROCEDURE [ReconciliationTests].[AddWritten]
    @Suffix            CHAR (1),
    @ActionCode        VARCHAR (30) = 'CREATE_PERSON_STUDENT',
    @Confirmed         BIT          = 1,
    @ReconciledBatchId BIGINT       = NULL
AS
BEGIN
    DECLARE @ApplicationId UNIQUEIDENTIFIER = CAST(CONCAT('B0000000-0000-4000-8000-00000000000', @Suffix) AS UNIQUEIDENTIFIER);
    DECLARE @Key BINARY (32) = HASHBYTES('SHA2_256', CAST(@Suffix AS VARCHAR (1)));
    DECLARE @IdNumber INT = 8000000 + CAST(@Suffix AS INT);

    INSERT INTO [integration].[OutboundStudentQueue] (
        [IdempotencyKey], [ApplicationId], [ActionCode], [QueueStatusCode], [ResultIdNumber], [J1ProgramCode], [ReconciledBatchId]
    )
    VALUES (@Key, @ApplicationId, @ActionCode, 'SUCCEEDED', @IdNumber, 'CIS.AS', @ReconciledBatchId);

    IF @Confirmed = 1
        INSERT INTO [integration].[vw_J1TargetStudent] ([IdempotencyKey], [IdNumber], [PersonExists], [ProgramCode], [StudentStatus])
        VALUES (@Key, @IdNumber, 1, 'CIS.AS', 'ACTIVE');
END;
GO

CREATE PROCEDURE [ReconciliationTests].[AddApplicants]
    @Count INT
AS
BEGIN
    DECLARE @I INT = 1;
    DECLARE @ApplicationId UNIQUEIDENTIFIER;
    DECLARE @PersonId UNIQUEIDENTIFIER;
    WHILE @I <= @Count
    BEGIN
        SET @ApplicationId = CAST(CONCAT('B0000000-0000-4000-8000-00000000000', @I) AS UNIQUEIDENTIFIER);
        SET @PersonId = CAST(CONCAT('A0000000-0000-4000-8000-00000000000', @I) AS UNIQUEIDENTIFIER);
        EXEC [IntegrationTestHelpers].[AddApplicant] @ApplicationId = @ApplicationId, @SlatePersonId = @PersonId;
        INSERT INTO [landing].[SlateApplicationRaw] ([ApplicationId]) VALUES (@ApplicationId);
        SET @I += 1;
    END;
END;
GO

CREATE PROCEDURE [ReconciliationTests].[test every eligible application gets exactly one outcome and the counts balance]
AS
BEGIN
    EXEC [ReconciliationTests].[AddApplicants] @Count = 6;
    EXEC [ReconciliationTests].[AddWritten] @Suffix = '1', @ActionCode = 'CREATE_PERSON_STUDENT';
    EXEC [ReconciliationTests].[AddWritten] @Suffix = '2', @ActionCode = 'READMIT_STUDENT';
    EXEC [ReconciliationTests].[AddWritten] @Suffix = '3', @ReconciledBatchId = 50;
    EXEC [IntegrationTestHelpers].[AddException] @ApplicationId = 'B0000000-0000-4000-8000-000000000004', @ReasonCode = 'INVALID_PROGRAM';
    INSERT INTO [integration].[OutboundStudentQueue] ([IdempotencyKey], [ApplicationId], [ActionCode], [QueueStatusCode])
    VALUES (0x05, 'B0000000-0000-4000-8000-000000000005', 'CREATE_PERSON_STUDENT', 'PENDING');
    UPDATE a SET a.[IsEligible] = 0 FROM [staging].[Applicant] AS a WHERE a.[ApplicationId] = 'B0000000-0000-4000-8000-000000000006';

    EXEC [integration].[usp_ReconcileSlateToJ1] @BatchId = 100;

    SELECT d.[ApplicationId], d.[OutcomeCode], d.[ExceptionReasonCode], d.[IsTargetConfirmed]
    INTO #Actual
    FROM [integration].[ReconciliationDetail] AS d;
    SELECT TOP (0) a.[ApplicationId], a.[OutcomeCode], a.[ExceptionReasonCode], a.[IsTargetConfirmed] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ApplicationId], [OutcomeCode], [ExceptionReasonCode], [IsTargetConfirmed])
    VALUES
        ('B0000000-0000-4000-8000-000000000001', 'CREATED', NULL, 1),
        ('B0000000-0000-4000-8000-000000000002', 'MATCHED', NULL, 1),
        ('B0000000-0000-4000-8000-000000000003', 'UNCHANGED', NULL, NULL),
        ('B0000000-0000-4000-8000-000000000004', 'REJECTED', 'INVALID_PROGRAM', NULL),
        ('B0000000-0000-4000-8000-000000000005', 'PENDING', NULL, NULL);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    SELECT
        r.[SourceEligible], r.[Unchanged], r.[Matched], r.[Created], r.[Rejected], r.[Pending], r.[Processed],
        r.[TargetConfirmed], r.[IsBalanced]
    INTO #ActualResult
    FROM [integration].[ReconciliationResult] AS r;
    SELECT TOP (0)
        a.[SourceEligible], a.[Unchanged], a.[Matched], a.[Created], a.[Rejected], a.[Pending], a.[Processed],
        a.[TargetConfirmed], a.[IsBalanced]
    INTO #ExpectedResult
    FROM #ActualResult AS a;
    INSERT INTO #ExpectedResult (
        [SourceEligible], [Unchanged], [Matched], [Created], [Rejected], [Pending], [Processed], [TargetConfirmed], [IsBalanced]
    )
    VALUES (5, 1, 1, 1, 1, 1, 2, 2, 1);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#ExpectedResult', @Actual = N'#ActualResult';
END;
GO

CREATE PROCEDURE [ReconciliationTests].[test an unconfirmed target leaves the run unbalanced and raises a mismatch]
AS
BEGIN
    EXEC [ReconciliationTests].[AddApplicants] @Count = 1;
    EXEC [ReconciliationTests].[AddWritten] @Suffix = '1', @Confirmed = 0;

    EXEC [integration].[usp_ReconcileSlateToJ1] @BatchId = 100;

    DECLARE @IsBalanced BIT = (SELECT r.[IsBalanced] FROM [integration].[ReconciliationResult] AS r);
    DECLARE @Reconciled BIGINT = (SELECT q.[ReconciledBatchId] FROM [integration].[OutboundStudentQueue] AS q);
    SELECT e.[ExceptionReasonCode], e.[SubjectBatchId], e.[DetailCode] INTO #Actual FROM [integration].[IntegrationException] AS e;
    SELECT TOP (0) a.[ExceptionReasonCode], a.[SubjectBatchId], a.[DetailCode] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ExceptionReasonCode], [SubjectBatchId], [DetailCode])
    VALUES ('RECONCILIATION_COUNT_MISMATCH', 100, 'TARGET_UNCONFIRMED:1');

    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @IsBalanced;
    EXEC tSQLt.AssertEquals @Expected = NULL, @Actual = @Reconciled, @Message = N'an unconfirmed row is reconciled again next run';
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ReconciliationTests].[test an entity count difference leaves the run unbalanced]
AS
BEGIN
    EXEC [ReconciliationTests].[AddApplicants] @Count = 1;
    INSERT INTO [landing].[J1PersonRaw] ([IdNumber]) VALUES (2400100);

    EXEC [integration].[usp_ReconcileSlateToJ1] @BatchId = 100;

    DECLARE @IsBalanced BIT = (SELECT r.[IsBalanced] FROM [integration].[ReconciliationResult] AS r);
    DECLARE @Detail VARCHAR (200) = (SELECT e.[DetailCode] FROM [integration].[IntegrationException] AS e);
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @IsBalanced;
    EXEC tSQLt.AssertEquals @Expected = 'J1_PERSON', @Actual = @Detail;
END;
GO

CREATE PROCEDURE [ReconciliationTests].[test a confirmed target closes reprocessed exceptions]
AS
BEGIN
    EXEC [ReconciliationTests].[AddApplicants] @Count = 1;
    EXEC [ReconciliationTests].[AddWritten] @Suffix = '1';
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'AMBIGUOUS_MATCH', @StatusCode = 'REPROCESSED';

    EXEC [integration].[usp_ReconcileSlateToJ1] @BatchId = 100;

    DECLARE @Status VARCHAR (30) = (SELECT e.[ExceptionStatusCode] FROM [integration].[IntegrationException] AS e);
    DECLARE @Reconciled BIGINT = (SELECT q.[ReconciledBatchId] FROM [integration].[OutboundStudentQueue] AS q);
    EXEC tSQLt.AssertEquals @Expected = 'CLOSED', @Actual = @Status;
    EXEC tSQLt.AssertEquals @Expected = 100, @Actual = @Reconciled;
END;
GO

CREATE PROCEDURE [ReconciliationTests].[test reconciling the same batch twice writes once]
AS
BEGIN
    EXEC [ReconciliationTests].[AddApplicants] @Count = 2;
    EXEC [ReconciliationTests].[AddWritten] @Suffix = '1';

    EXEC [integration].[usp_ReconcileSlateToJ1] @BatchId = 100;
    EXEC [integration].[usp_ReconcileSlateToJ1] @BatchId = 100;

    DECLARE @Details INT = (SELECT COUNT(*) FROM [integration].[ReconciliationDetail]);
    DECLARE @Results INT = (SELECT COUNT(*) FROM [integration].[ReconciliationResult]);
    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @Details;
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Results;
END;
GO

CREATE PROCEDURE [ReconciliationTests].[test the database rejects a summary whose outcomes do not add up]
AS
BEGIN
    EXEC tSQLt.ApplyConstraint
        @TableName = N'integration.ReconciliationResult', @ConstraintName = N'CK_integration_ReconciliationResult_OutcomesEqualEligible';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 547;

    INSERT INTO [integration].[ReconciliationResult] (
        [BatchId], [SourceEligible], [Unchanged], [Matched], [Created], [Rejected], [Pending], [TargetConfirmed], [EntityMismatchCount]
    )
    VALUES (100, 10, 2, 2, 2, 2, 1, 4, 0);
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [ReconciliationTests].[test the summary step fails when the run is not balanced]
AS
BEGIN
    INSERT INTO [integration].[ReconciliationResult] (
        [BatchId], [SourceEligible], [Unchanged], [Matched], [Created], [Rejected], [Pending], [TargetConfirmed], [EntityMismatchCount]
    )
    VALUES (100, 1, 0, 0, 1, 0, 0, 0, 0);

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 50401;
    EXEC [integration].[usp_PublishRunSummary] @BatchId = 100;
END;
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'integration';
GO
