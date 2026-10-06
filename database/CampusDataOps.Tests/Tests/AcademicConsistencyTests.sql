/*
tSQLt tests for the Part 3 data-quality rules (credential before completion, status consistency)
and issue dispositions. Core views are faked through helper procedures; SetFakeViewOn lets them
insert into multi-table views and is switched off at the end of this file.
*/
EXEC tSQLt.NewTestClass @ClassName = N'AcademicConsistencyTests';
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'core';
GO

EXEC tSQLt.SetFakeViewOn @SchemaName = N'core';
GO

CREATE PROCEDURE [AcademicConsistencyTests].[AddData]
AS
BEGIN
    INSERT INTO [core].[vw_Student] ([IdNumber], [StudentStatus])
    VALUES (1, 'GRADUATED'), (2, 'GRADUATED'), (3, 'WITHDRAWN'), (4, 'ACTIVE');
    -- Student 1 earns 30 credits before the award; student 2 only 27 (one F).
    INSERT INTO [core].[vw_Credential] ([CredentialAwardedId], [IdNumber], [TermCode], [RequiredCredits])
    VALUES (10, 1, '2026SP', 30.0), (20, 2, '2026SP', 30.0);
    INSERT INTO [core].[vw_Enrollment] (
        [EnrollmentId], [IdNumber], [TermCode], [CreditHours], [GradePoints], [IsAttempted], [RegistrationStatus]
    )
    VALUES
        (1, 1, '2025FA', 15.0, 3.00, 1, 'REGISTERED'), (2, 1, '2026SP', 15.0, 1.00, 1, 'REGISTERED'),
        (3, 2, '2025FA', 15.0, 3.00, 1, 'REGISTERED'), (4, 2, '2026SP', 12.0, 2.00, 1, 'REGISTERED'),
        (5, 2, '2026SP', 3.0, 0.00, 1, 'REGISTERED'), (6, 2, '2026FA', 3.0, NULL, 1, 'REGISTERED'),
        (7, 3, '2027SP', 3.0, NULL, 1, 'REGISTERED');
END;
GO

CREATE PROCEDURE [AcademicConsistencyTests].[SetUp]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Student';
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Credential';
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Enrollment';
    EXEC tSQLt.FakeTable @TableName = N'reference.AcademicTerm';
    EXEC tSQLt.FakeTable @TableName = N'dq.RuleExecution';
    EXEC tSQLt.FakeTable @TableName = N'dq.RuleResult', @Identity = 1;

    INSERT INTO [reference].[AcademicTerm] ([TermCode], [StartDate], [EndDate])
    VALUES ('2025FA', '2025-09-02', '2025-12-19'), ('2026SP', '2026-01-20', '2026-05-15'), ('2026FA', '2026-09-02', '2026-12-19'),
        ('2027SP', '2099-01-20', '2099-05-15');
    EXEC [AcademicConsistencyTests].[AddData];
END;
GO

CREATE PROCEDURE [AcademicConsistencyTests].[test inconsistent credentials and statuses are reported with codes]
AS
BEGIN
    EXEC [dq].[usp_CheckAcademicConsistency] @ValidationRunId = 1;

    SELECT r.[RuleCode], r.[RecordKey], r.[DetailCode] INTO #Actual FROM [dq].[RuleResult] AS r;
    SELECT TOP (0) a.[RuleCode], a.[RecordKey], a.[DetailCode] INTO #Expected FROM #Actual AS a;
    -- A later term's credits (2026FA) do not count toward a 2026SP award.
    INSERT INTO #Expected ([RuleCode], [RecordKey], [DetailCode])
    VALUES
        ('CRED_EARNED_CREDITS', '20', 'EARNED_27.0_OF_30.0'),
        ('STU_STATUS_CONSISTENT', '3', 'WITHDRAWN_FUTURE_REGISTRATION');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [AcademicConsistencyTests].[test a new disposition supersedes the current one]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'dq.IssueDisposition', @Identity = 1, @Defaults = 1;
    INSERT INTO [dq].[RuleResult] ([ValidationRunId], [RuleCode], [RecordKey]) VALUES (1, 'CRED_EARNED_CREDITS', '20');

    EXEC [dq].[usp_RecordIssueDisposition]
        @RuleCode = 'CRED_EARNED_CREDITS', @RecordKey = '20', @DispositionCode = 'ACCEPTED_EXCEPTION',
        @Note = N'Transfer credit not yet in J1-Sim.', @ReviewBy = '2026-12-31';
    EXEC [dq].[usp_RecordIssueDisposition]
        @RuleCode = 'CRED_EARNED_CREDITS', @RecordKey = '20', @DispositionCode = 'FIX_IN_SOURCE', @Note = N'Registrar will correct.';

    SELECT d.[DispositionCode], d.[IsCurrent] INTO #Actual FROM [dq].[IssueDisposition] AS d;
    SELECT TOP (0) a.[DispositionCode], a.[IsCurrent] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([DispositionCode], [IsCurrent]) VALUES ('ACCEPTED_EXCEPTION', 0), ('FIX_IN_SOURCE', 1);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [AcademicConsistencyTests].[test an accepted exception needs a review date]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'dq.IssueDisposition';
    EXEC tSQLt.ApplyConstraint @TableName = N'dq.IssueDisposition', @ConstraintName = N'CK_dq_IssueDisposition_AcceptedNeedsReview';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 547;
    INSERT INTO [dq].[IssueDisposition] ([RuleCode], [RecordKey], [DispositionCode], [Note], [IsCurrent])
    VALUES ('CRED_EARNED_CREDITS', '20', 'ACCEPTED_EXCEPTION', N'no review date', 1);
END;
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'core';
GO
