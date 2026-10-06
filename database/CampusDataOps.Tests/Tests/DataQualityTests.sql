/*
tSQLt tests for the data-quality suite (docs/specifications/data-quality-rules.md). Each test
stages one passing and one failing record so a rule that flags everything also fails.
*/
EXEC tSQLt.NewTestClass @ClassName = N'DataQualityTests';
GO

CREATE PROCEDURE [DataQualityTests].[SetUp]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[FakeAll];
    EXEC tSQLt.FakeTable @TableName = N'staging.Enrollment';
    EXEC tSQLt.FakeTable @TableName = N'staging.FinancialAidAward';
    EXEC tSQLt.FakeTable @TableName = N'staging.AccountTransaction';
    EXEC tSQLt.FakeTable @TableName = N'staging.CredentialAwarded';
    EXEC tSQLt.FakeTable @TableName = N'staging.DirectoryAccount';
    EXEC tSQLt.FakeTable @TableName = N'landing.J1AccountControlTotal';
    EXEC tSQLt.FakeTable @TableName = N'reference.AcademicTerm';
    EXEC tSQLt.FakeTable @TableName = N'dq.ValidationRun', @Identity = 1;
    EXEC tSQLt.FakeTable @TableName = N'dq.RuleExecution';
    EXEC tSQLt.FakeTable @TableName = N'dq.RuleResult', @Identity = 1;

    INSERT INTO [reference].[AcademicTerm] ([TermCode], [AcademicYear], [IsOpenForAdmission])
    VALUES ('2026FA', '2026-2027', 0), ('2027SP', '2026-2027', 1);
END;
GO

CREATE PROCEDURE [DataQualityTests].[AssertFailures]
    @RuleCode VARCHAR (40),
    @Expected NVARCHAR (MAX)
AS
BEGIN
    -- @Expected is a semicolon-separated list of RecordKey:DetailCode pairs, or empty for none.
    SELECT rr.[RecordKey], rr.[DetailCode] INTO #Actual FROM [dq].[RuleResult] AS rr WHERE rr.[RuleCode] = @RuleCode;
    SELECT TOP (0) a.[RecordKey], a.[DetailCode] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([RecordKey], [DetailCode])
    SELECT
        LEFT(v.[value], CHARINDEX(':', v.[value]) - 1) AS [RecordKey],
        SUBSTRING(v.[value], CHARINDEX(':', v.[value]) + 1, 200) AS [DetailCode]
    FROM STRING_SPLIT(@Expected, ';') AS v
    WHERE v.[value] <> '';

    DECLARE @Message NVARCHAR (200) = CONCAT(N'Failures for ', @RuleCode);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual', @Message = @Message;
END;
GO

CREATE PROCEDURE [DataQualityTests].[test applicant rules flag only the failing applications]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000001', @SlatePersonId = 'A0000000-0000-4000-8000-000000000001',
        @Email = N'valid@example.com';
    EXEC [IntegrationTestHelpers].[AddApplicant]
        @ApplicationId = 'B0000000-0000-4000-8000-000000000002', @SlatePersonId = 'A0000000-0000-4000-8000-000000000002';
    UPDATE a
    SET a.[MissingRequiredFields] = 'PROGRAM', a.[J1ProgramCode] = NULL, a.[ProgramValidationCode] = 'MISSING',
        a.[EntryTermCode] = NULL, a.[TermValidationCode] = 'UNKNOWN_TERM', a.[EmailRaw] = N'a@@b.com', a.[IsEmailValid] = 0,
        a.[DuplicateApplicationCount] = 2
    FROM [staging].[Applicant] AS a
    WHERE a.[ApplicationId] = 'B0000000-0000-4000-8000-000000000002';

    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'APP_REQUIRED_FIELDS', @Expected = N'B0000000-0000-4000-8000-000000000002:PROGRAM';
    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'APP_TERM_VALID', @Expected = N'B0000000-0000-4000-8000-000000000002:UNKNOWN_TERM';
    EXEC [DataQualityTests].[AssertFailures]
        @RuleCode = 'APP_EMAIL_FORMAT', @Expected = N'B0000000-0000-4000-8000-000000000002:INVALID_EMAIL';
    EXEC [DataQualityTests].[AssertFailures]
        @RuleCode = 'APP_DUPLICATE_APPLICATION', @Expected = N'B0000000-0000-4000-8000-000000000002:GROUP_SIZE:2';
    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'APP_PROGRAM_VALID', @Expected = N'';
END;
GO

CREATE PROCEDURE [DataQualityTests].[test people sharing name, birth date and postal code are flagged as a group]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000001, @FirstName = N'MORGAN', @LastName = N'ELLSWORTH';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000002, @FirstName = N'MORGAN', @LastName = N'ELLSWORTH';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @FirstName = N'MORGAN', @LastName = N'ELLSWORTH', @PostalCode5 = '02139';

    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    EXEC [DataQualityTests].[AssertFailures]
        @RuleCode = 'SIS_DUPLICATE_PERSON', @Expected = N'9000001:GROUP:9000001;9000002:GROUP:9000001';
END;
GO

CREATE PROCEDURE [DataQualityTests].[test enrollment rules]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @StudentStatus = 'ACTIVE';
    INSERT INTO [staging].[Enrollment] ([EnrollmentId], [IdNumber], [TermCode], [RegistrationStatus], [GradeCode])
    VALUES
        (1, 2400100, '2026FA', 'REGISTERED', 'A'),
        (2, 2400999, '2026FA', 'REGISTERED', NULL),
        (3, 2400100, '2019FA', 'REGISTERED', NULL),
        (4, 2400100, '2026FA', 'DROPPED', 'B'),
        (5, 2400100, '2026FA', 'WITHDRAWN', 'W');

    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'ENR_STUDENT_EXISTS', @Expected = N'2:NO_STUDENT_RECORD';
    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'ENR_TERM_VALID', @Expected = N'3:UNKNOWN_TERM';
    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'ENR_GRADE_STATUS', @Expected = N'4:DROPPED_WITH_GRADE';
END;
GO

CREATE PROCEDURE [DataQualityTests].[test aid period and disbursement rules]
AS
BEGIN
    INSERT INTO [staging].[Enrollment] ([EnrollmentId], [IdNumber], [TermCode], [RegistrationStatus])
    VALUES (1, 2400100, '2026FA', 'REGISTERED'), (2, 2400200, '2026FA', 'DROPPED');
    INSERT INTO [staging].[FinancialAidAward] ([AwardId], [IdNumber], [AidYear], [TermCode], [DisbursedAmount])
    VALUES
        (11, 2400100, '2026-2027', '2026FA', 1000.00),
        (12, 2400200, '2026-2027', '2026FA', 500.00),
        (13, 2400100, '2025-2026', '2027SP', 0.00),
        (14, 2400100, '2026-2027', '2031FA', 0.00);

    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'AID_PERIOD_VALID', @Expected = N'13:AID_YEAR_MISMATCH;14:UNKNOWN_TERM';
    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'AID_DISBURSED_ENROLLED', @Expected = N'12:NO_REGISTERED_ENROLLMENT';
END;
GO

CREATE PROCEDURE [DataQualityTests].[test directory rules find missing and orphan accounts]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400100, @StudentStatus = 'ACTIVE';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 2400200, @FirstName = N'ROWAN', @StudentStatus = 'ACTIVE';
    INSERT INTO [staging].[DirectoryAccount] ([AccountGuid], [AccountType], [IsEnabled], [EmployeeIdNumber])
    VALUES
        ('C0000000-0000-4000-8000-000000000001', 'STUDENT', 1, 2400100),
        ('C0000000-0000-4000-8000-000000000002', 'STUDENT', 0, 2400200),
        ('C0000000-0000-4000-8000-000000000099', 'STUDENT', 1, 9000099),
        ('C0000000-0000-4000-8000-000000000098', 'STAFF', 1, NULL);

    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    EXEC [DataQualityTests].[AssertFailures] @RuleCode = 'DIR_ACTIVE_STUDENT_ACCOUNT', @Expected = N'2400200:NO_ENABLED_STUDENT_ACCOUNT';
    EXEC [DataQualityTests].[AssertFailures]
        @RuleCode = 'DIR_ORPHAN_ACCOUNT', @Expected = N'C0000000-0000-4000-8000-000000000099:NOT_A_J1_PERSON';
END;
GO

CREATE PROCEDURE [DataQualityTests].[test staged account detail must equal the latest source control total]
AS
BEGIN
    INSERT INTO [staging].[AccountTransaction] ([TransactionId], [IdNumber], [TermCode], [Amount])
    VALUES (1, 2400100, '2026FA', 1200.00), (2, 2400100, '2026FA', -200.00), (3, 2400200, '2026FA', 900.00);
    INSERT INTO [landing].[J1AccountControlTotal] ([BatchId], [IdNumber], [TermCode], [TransactionCount], [AmountTotal])
    VALUES
        (1, 2400100, '2026FA', 1, 1200.00),
        (2, 2400100, '2026FA', 2, 1000.00),
        (2, 2400200, '2026FA', 2, 1800.00);

    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    EXEC [DataQualityTests].[AssertFailures]
        @RuleCode = 'ACCT_DETAIL_TO_TOTAL', @Expected = N'2400200|2026FA:COUNT_DIFFERS,AMOUNT_DIFFERS';
END;
GO

CREATE PROCEDURE [DataQualityTests].[test an application written without a crosswalk is flagged]
AS
BEGIN
    INSERT INTO [integration].[OutboundStudentQueue] ([IdempotencyKey], [ApplicationId], [SlatePersonId], [QueueStatusCode])
    VALUES
        (0x01, 'B0000000-0000-4000-8000-000000000001', 'A0000000-0000-4000-8000-000000000001', 'SUCCEEDED'),
        (0x02, 'B0000000-0000-4000-8000-000000000002', 'A0000000-0000-4000-8000-000000000002', 'SUCCEEDED');
    INSERT INTO [integration].[SourceCrosswalk] ([SourceSystemCode], [SourceRecordId], [TargetIdNumber])
    VALUES ('SLATE_SIM', 'A0000000-0000-4000-8000-000000000001', 8000001);

    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    EXEC [DataQualityTests].[AssertFailures]
        @RuleCode = 'INT_CROSSWALK_PRESENT', @Expected = N'B0000000-0000-4000-8000-000000000002:NO_CROSSWALK';
END;
GO

CREATE PROCEDURE [DataQualityTests].[test an inactive rule is not evaluated]
AS
BEGIN
    UPDATE r SET r.[IsActive] = 0 FROM [dq].[Rule] AS r WHERE r.[RuleCode] = 'SIS_DUPLICATE_PERSON';
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000001;
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000002;

    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    DECLARE @Executions INT = (SELECT COUNT(*) FROM [dq].[RuleExecution] AS x WHERE x.[RuleCode] = 'SIS_DUPLICATE_PERSON');
    DECLARE @Results INT = (SELECT COUNT(*) FROM [dq].[RuleResult] AS rr WHERE rr.[RuleCode] = 'SIS_DUPLICATE_PERSON');
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Executions;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Results;
END;
GO

CREATE PROCEDURE [DataQualityTests].[test every active rule records an execution even with nothing to evaluate]
AS
BEGIN
    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100;

    DECLARE @Executions INT = (SELECT COUNT(*) FROM [dq].[RuleExecution]);
    DECLARE @ActiveRules INT = (SELECT COUNT(*) FROM [dq].[Rule] AS r WHERE r.[IsActive] = 1);
    DECLARE @Evaluated INT = (SELECT SUM(x.[RecordsEvaluated]) FROM [dq].[RuleExecution] AS x);
    EXEC tSQLt.AssertEquals @Expected = @ActiveRules, @Actual = @Executions;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Evaluated;
END;
GO

CREATE PROCEDURE [DataQualityTests].[test running the suite twice for a batch writes one run]
AS
BEGIN
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000001;
    EXEC [IntegrationTestHelpers].[AddPerson] @IdNumber = 9000002;

    DECLARE @FirstRun BIGINT;
    DECLARE @SecondRun BIGINT;
    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100, @ValidationRunId = @FirstRun OUTPUT;
    EXEC [dq].[usp_RunDataQualitySuite] @BatchId = 100, @ValidationRunId = @SecondRun OUTPUT;

    DECLARE @Runs INT = (SELECT COUNT(*) FROM [dq].[ValidationRun]);
    DECLARE @Results INT = (SELECT COUNT(*) FROM [dq].[RuleResult]);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Runs;
    EXEC tSQLt.AssertEquals @Expected = @FirstRun, @Actual = @SecondRun;
    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @Results;
END;
GO
