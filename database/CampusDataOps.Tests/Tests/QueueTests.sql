/*
tSQLt tests for the outbound queue and its processing
(docs/specifications/integration-controls.md). The J1-Sim adapter is replaced with a spy, so
no test writes to the SourceSystems database.
*/
EXEC tSQLt.NewTestClass @ClassName = N'QueueTests';
GO

CREATE PROCEDURE [QueueTests].[SetUp]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[FakeAll];
    EXEC tSQLt.FakeTable @TableName = N'audit.BatchRun';
    INSERT INTO [audit].[BatchRun] ([BatchId], [ProcessName], [BatchStatusCode]) VALUES (100, 'TEST', 'RUNNING'), (101, 'TEST', 'RUNNING');
END;
GO

CREATE PROCEDURE [QueueTests].[AddReadyApplicant]
    @Suffix           CHAR (1),
    @DecisionTypeCode VARCHAR (20) = 'NEW_PERSON',
    @MatchedIdNumber  INT          = NULL
AS
BEGIN
    DECLARE @ApplicationId UNIQUEIDENTIFIER = CAST(CONCAT('B0000000-0000-4000-8000-00000000000', @Suffix) AS UNIQUEIDENTIFIER);
    DECLARE @PersonId UNIQUEIDENTIFIER = CAST(CONCAT('A0000000-0000-4000-8000-00000000000', @Suffix) AS UNIQUEIDENTIFIER);
    EXEC [IntegrationTestHelpers].[AddApplicant] @ApplicationId = @ApplicationId, @SlatePersonId = @PersonId;
    EXEC [IntegrationTestHelpers].[AddDecision]
        @ApplicationId = @ApplicationId, @DecisionTypeCode = @DecisionTypeCode, @MatchedIdNumber = @MatchedIdNumber;
END;
GO

CREATE PROCEDURE [QueueTests].[test each kind of decision gets the right action]
AS
BEGIN
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100;
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '2', @DecisionTypeCode = 'AUTO_MATCH', @MatchedIdNumber = 2400100;
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400200, @StudentStatus = 'GRADUATED';
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '3', @DecisionTypeCode = 'MANUAL_MATCH', @MatchedIdNumber = 2400200;

    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;

    SELECT q.[ApplicationId], q.[ActionCode], q.[TargetIdNumber], q.[QueueStatusCode] INTO #Actual FROM [integration].[OutboundStudentQueue] AS q;
    SELECT TOP (0) a.[ApplicationId], a.[ActionCode], a.[TargetIdNumber], a.[QueueStatusCode] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ApplicationId], [ActionCode], [TargetIdNumber], [QueueStatusCode])
    VALUES
        ('B0000000-0000-4000-8000-000000000001', 'CREATE_PERSON_STUDENT', NULL, 'PENDING'),
        ('B0000000-0000-4000-8000-000000000002', 'CREATE_STUDENT', 2400100, 'PENDING'),
        ('B0000000-0000-4000-8000-000000000003', 'READMIT_STUDENT', 2400200, 'PENDING');
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [QueueTests].[test an applicant who is already an active student is not queued]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @StudentStatus = 'ACTIVE';
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1', @DecisionTypeCode = 'AUTO_MATCH', @MatchedIdNumber = 2400100;

    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;

    DECLARE @Queued INT = (SELECT COUNT(*) FROM [integration].[OutboundStudentQueue]);
    DECLARE @Reason VARCHAR (40) = (SELECT e.[ExceptionReasonCode] FROM [integration].[IntegrationException] AS e);
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Queued;
    EXEC tSQLt.AssertEquals @Expected = 'ALREADY_MATRICULATED', @Actual = @Reason;
END;
GO

CREATE PROCEDURE [QueueTests].[test queueing the same decision again keeps one row]
AS
BEGIN
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';

    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;
    EXEC [integration].[usp_RunQueueStep] @BatchId = 101;

    DECLARE @Rows INT = (SELECT COUNT(*) FROM [integration].[OutboundStudentQueue]);
    DECLARE @QueuedBatch BIGINT = (SELECT q.[QueuedBatchId] FROM [integration].[OutboundStudentQueue] AS q);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Rows;
    EXEC tSQLt.AssertEquals @Expected = 100, @Actual = @QueuedBatch;
END;
GO

CREATE PROCEDURE [QueueTests].[test a blocked application is not queued]
AS
BEGIN
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'DUPLICATE_APPLICATION';

    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;

    DECLARE @Rows INT = (SELECT COUNT(*) FROM [integration].[OutboundStudentQueue]);
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Rows;
END;
GO

CREATE PROCEDURE [QueueTests].[test a changed decision cancels the unsent row and queues the new one]
AS
BEGIN
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';
    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;

    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100;
    UPDATE d SET d.[IsCurrent] = 0, d.[SupersededAtUtc] = SYSUTCDATETIME() FROM [integration].[MatchDecision] AS d;
    EXEC [IntegrationTestHelpers].[AddDecision]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @DecisionTypeCode = 'MANUAL_MATCH', @MatchedIdNumber = 2400100;
    EXEC [integration].[usp_RunQueueStep] @BatchId = 101;

    SELECT q.[ActionCode], q.[QueueStatusCode] INTO #Actual FROM [integration].[OutboundStudentQueue] AS q;
    SELECT TOP (0) a.[ActionCode], a.[QueueStatusCode] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ActionCode], [QueueStatusCode]) VALUES ('CREATE_PERSON_STUDENT', 'CANCELLED'), ('CREATE_STUDENT', 'PENDING');
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [QueueTests].[test a successful write records the result, the crosswalk and reprocesses retry-ready exceptions]
AS
BEGIN
    EXEC tSQLt.SpyProcedure @ProcedureName = N'integration.usp_WriteApplicantToSis', @CommandToExecute = N'SET @ResultIdNumber = 8000001;';
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';
    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'INVALID_PROGRAM', @StatusCode = 'RETRY_READY';

    EXEC [integration].[usp_ProcessOutboundQueue] @BatchId = 100;

    SELECT q.[QueueStatusCode], q.[ResultIdNumber], q.[AttemptCount], q.[ProcessedBatchId]
    INTO #Actual
    FROM [integration].[OutboundStudentQueue] AS q;
    SELECT TOP (0) a.[QueueStatusCode], a.[ResultIdNumber], a.[AttemptCount], a.[ProcessedBatchId] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([QueueStatusCode], [ResultIdNumber], [AttemptCount], [ProcessedBatchId]) VALUES ('SUCCEEDED', 8000001, 1, 100);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    DECLARE @Target INT = (
        SELECT c.[TargetIdNumber] FROM [integration].[SourceCrosswalk] AS c
        WHERE c.[SourceRecordId] = 'A0000000-0000-4000-8000-000000000001'
    );
    DECLARE @Status VARCHAR (30) = (SELECT e.[ExceptionStatusCode] FROM [integration].[IntegrationException] AS e);
    EXEC tSQLt.AssertEquals @Expected = 8000001, @Actual = @Target;
    EXEC tSQLt.AssertEquals @Expected = 'REPROCESSED', @Actual = @Status;
END;
GO

CREATE PROCEDURE [QueueTests].[test a succeeded row is never sent again]
AS
BEGIN
    EXEC tSQLt.SpyProcedure @ProcedureName = N'integration.usp_WriteApplicantToSis', @CommandToExecute = N'SET @ResultIdNumber = 8000001;';
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';
    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;

    EXEC [integration].[usp_ProcessOutboundQueue] @BatchId = 100;
    EXEC [integration].[usp_RunQueueStep] @BatchId = 101;
    EXEC [integration].[usp_ProcessOutboundQueue] @BatchId = 101;

    DECLARE @Calls INT = (SELECT COUNT(*) FROM [integration].[usp_WriteApplicantToSis_SpyProcedureLog]);
    DECLARE @Rows INT = (SELECT COUNT(*) FROM [integration].[OutboundStudentQueue]);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Calls;
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Rows;
END;
GO

-- Mid-batch failure: the second of three writes fails. The procedure rolls back that row's
-- transaction, so the test runs outside tSQLt's transaction.
--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [QueueTests].[test a failed write is isolated, logged and fails the step after the other rows]
AS
BEGIN
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '2';
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '3';
    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;
    EXEC tSQLt.SpyProcedure
        @ProcedureName = N'integration.usp_WriteApplicantToSis',
        @CommandToExecute = N'IF @QueueId = 2 THROW 50999, N''Simulated SIS outage.'', 1; SET @ResultIdNumber = 8000000 + @QueueId;';

    DECLARE @ErrorNumber INT;
    BEGIN TRY
        EXEC [integration].[usp_ProcessOutboundQueue] @BatchId = 100, @BatchStepId = 7;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
    END CATCH;

    SELECT
        CAST(q.[QueueId] AS BIGINT) AS [QueueId], q.[QueueStatusCode], q.[AttemptCount], q.[ResultIdNumber],
        CAST(CASE WHEN q.[LastErrorLogId] IS NULL THEN 0 ELSE 1 END AS BIT) AS [HasError]
    INTO #Actual
    FROM [integration].[OutboundStudentQueue] AS q;
    SELECT TOP (0) a.[QueueId], a.[QueueStatusCode], a.[AttemptCount], a.[ResultIdNumber], a.[HasError] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([QueueId], [QueueStatusCode], [AttemptCount], [ResultIdNumber], [HasError])
    VALUES (1, 'SUCCEEDED', 1, 8000001, 0), (2, 'FAILED_RETRYABLE', 1, NULL, 1), (3, 'SUCCEEDED', 1, 8000003, 0);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    DECLARE @LoggedNumber INT = (SELECT e.[ErrorNumber] FROM [audit].[ErrorLog] AS e WHERE e.[BatchId] = 100);
    DECLARE @Crosswalks INT = (SELECT COUNT(*) FROM [integration].[SourceCrosswalk]);
    EXEC tSQLt.AssertEquals @Expected = 50300, @Actual = @ErrorNumber, @Message = N'the step fails after finishing';
    EXEC tSQLt.AssertEquals @Expected = 50999, @Actual = @LoggedNumber, @Message = N'the cause is logged against the batch';
    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @Crosswalks, @Message = N'no crosswalk for the failed row';
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [QueueTests].[test reaching the attempt limit raises an outbound write failure]
AS
BEGIN
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';
    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;
    UPDATE q SET q.[AttemptCount] = 2, q.[QueueStatusCode] = 'FAILED_RETRYABLE' FROM [integration].[OutboundStudentQueue] AS q;
    EXEC tSQLt.SpyProcedure
        @ProcedureName = N'integration.usp_WriteApplicantToSis', @CommandToExecute = N'THROW 51001, N''Program is not active.'', 1;';

    DECLARE @ErrorNumber INT;
    BEGIN TRY
        EXEC [integration].[usp_ProcessOutboundQueue] @BatchId = 100;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
    END CATCH;

    EXEC tSQLt.AssertEquals @Expected = 50300, @Actual = @ErrorNumber;
    DECLARE @Status VARCHAR (20) = (SELECT q.[QueueStatusCode] FROM [integration].[OutboundStudentQueue] AS q);
    SELECT e.[ExceptionReasonCode], e.[ExceptionStatusCode], e.[DetailCode] INTO #Actual FROM [integration].[IntegrationException] AS e;
    SELECT TOP (0) a.[ExceptionReasonCode], a.[ExceptionStatusCode], a.[DetailCode] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ExceptionReasonCode], [ExceptionStatusCode], [DetailCode]) VALUES ('OUTBOUND_WRITE_FAILURE', 'OPEN', 'ERROR:51001');

    EXEC tSQLt.AssertEquals @Expected = 'FAILED_PERMANENT', @Actual = @Status;
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [QueueTests].[test resolving an outbound write failure resets the row for retry]
AS
BEGIN
    EXEC [QueueTests].[AddReadyApplicant] @Suffix = '1';
    EXEC [integration].[usp_RunQueueStep] @BatchId = 100;
    UPDATE q SET q.[AttemptCount] = 3, q.[QueueStatusCode] = 'FAILED_PERMANENT' FROM [integration].[OutboundStudentQueue] AS q;
    DECLARE @ExceptionId BIGINT;
    EXEC [IntegrationTestHelpers].[AddException]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @ReasonCode = 'OUTBOUND_WRITE_FAILURE', @ExceptionId = @ExceptionId OUTPUT;

    EXEC [integration].[usp_TransitionException]
        @ExceptionId = @ExceptionId, @ToStatusCode = 'RESOLVED', @ReasonText = N'Program reactivated by the Registrar';
    EXEC [integration].[usp_RunQueueStep] @BatchId = 101;

    SELECT q.[QueueStatusCode], q.[AttemptCount], q.[RetryGeneration] INTO #Actual FROM [integration].[OutboundStudentQueue] AS q;
    SELECT TOP (0) a.[QueueStatusCode], a.[AttemptCount], a.[RetryGeneration] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([QueueStatusCode], [AttemptCount], [RetryGeneration]) VALUES ('PENDING', 0, 1);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    DECLARE @Status VARCHAR (30) = (SELECT e.[ExceptionStatusCode] FROM [integration].[IntegrationException] AS e);
    EXEC tSQLt.AssertEquals @Expected = 'RETRY_READY', @Actual = @Status;
END;
GO
