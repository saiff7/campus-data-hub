/*
tSQLt tests for the six reports (docs/specifications/report-catalog.md): grains, boundary
dates, inclusion and exclusion rules, aging buckets, aggregate totals, masking and the audited
drill-through. Core views are faked through helper procedures; SetFakeViewOn lets those
procedures insert into multi-table views and is switched off at the end of this file.
*/
EXEC tSQLt.NewTestClass @ClassName = N'ReportingTests';
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'core';
GO

EXEC tSQLt.SetFakeViewOn @SchemaName = N'core';
GO

CREATE PROCEDURE [ReportingTests].[AddTransaction]
    @TransactionId BIGINT,
    @Amount        DECIMAL (12, 2),
    @PostedDate    DATE,
    @DueDate       DATE         = NULL,
    @Type          VARCHAR (12) = 'CHARGE',
    @IdNumber      INT          = 2400001
AS
BEGIN
    INSERT INTO [core].[vw_AccountTransaction] (
        [TransactionId], [IdNumber], [TransactionType], [Amount], [PostedDate], [DueDate], [EffectiveDueDate]
    )
    VALUES (@TransactionId, @IdNumber, @Type, @Amount, @PostedDate, @DueDate, COALESCE(@DueDate, @PostedDate));
END;
GO

CREATE PROCEDURE [ReportingTests].[AddAward]
    @AwardId   BIGINT,
    @FundCode  VARCHAR (15),
    @Status    VARCHAR (10),
    @Offered   DECIMAL (12, 2),
    @Accepted  DECIMAL (12, 2) = 0,
    @Disbursed DECIMAL (12, 2) = 0,
    @TermCode  VARCHAR (10)    = '2025FA'
AS
BEGIN
    INSERT INTO [core].[vw_AidAward] (
        [AwardId], [IdNumber], [AidYear], [TermCode], [FundCode], [FundSource], [FundType], [AwardStatus], [OfferedAmount],
        [AcceptedAmount], [DisbursedAmount]
    )
    VALUES (@AwardId, 2400001, '2025-2026', @TermCode, @FundCode, 'FEDERAL', 'GRANT', @Status, @Offered, @Accepted, @Disbursed);
END;
GO

CREATE PROCEDURE [ReportingTests].[AddGrade]
    @EnrollmentId BIGINT,
    @TermCode     VARCHAR (10),
    @Credits      DECIMAL (4, 1),
    @GradeCode    VARCHAR (2),
    @GradePoints  DECIMAL (3, 2),
    @Status       VARCHAR (15) = 'REGISTERED'
AS
BEGIN
    INSERT INTO [core].[vw_Enrollment] (
        [EnrollmentId], [IdNumber], [TermCode], [CreditHours], [RegistrationStatus], [GradeCode], [GradePoints], [IsAttempted]
    )
    VALUES (
        @EnrollmentId, 2400001, @TermCode, @Credits, @Status, @GradeCode, @GradePoints,
        CASE WHEN @Status = 'DROPPED' THEN 0 ELSE 1 END
    );
END;
GO

CREATE PROCEDURE [ReportingTests].[AddProgressContext]
AS
BEGIN
    INSERT INTO [core].[vw_Student] ([IdNumber], [ProgramCode]) VALUES (2400001, 'WELD.CERT');
END;
GO

CREATE PROCEDURE [ReportingTests].[AddCredential]
    @TermCode VARCHAR (10)
AS
BEGIN
    INSERT INTO [core].[vw_Credential] ([CredentialAwardedId], [IdNumber], [ProgramCode], [TermCode], [AwardedDate])
    VALUES (1, 2400001, 'WELD.CERT', @TermCode, '2026-05-20');
END;
GO

------------------------------------------------------------------------------------------
-- R1 Enrollment census
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ReportingTests].[test the census report refuses a term without a snapshot]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusSnapshot';
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusSnapshotEnrollment';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52201;
    EXEC [reporting].[usp_ReportEnrollmentByTerm] @TermCode = '2026FA';
END;
GO

CREATE PROCEDURE [ReportingTests].[test the census view reads only the current rule version]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusSnapshot';
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusSnapshotEnrollment';
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusRuleVersion';

    INSERT INTO [compliance].[CensusRuleVersion] ([RuleVersion], [IsCurrent]) VALUES ('OLD', 0), ('NEW', 1);
    INSERT INTO [compliance].[CensusSnapshot] ([CensusSnapshotId], [TermCode], [RuleVersion])
    VALUES (1, '2025FA', 'OLD'), (2, '2025FA', 'NEW');
    INSERT INTO [compliance].[CensusSnapshotEnrollment] ([CensusSnapshotId], [IdNumber], [IsCensusIncluded], [CensusCredits])
    VALUES (1, 2400001, 1, 12.0), (2, 2400001, 1, 9.0);

    SELECT c.[CensusSnapshotId], c.[CensusCredits] INTO #Actual FROM [reporting].[vw_EnrollmentCensus] AS c;
    SELECT TOP (0) a.[CensusSnapshotId], a.[CensusCredits] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([CensusSnapshotId], [CensusCredits]) VALUES (2, 9.0);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

------------------------------------------------------------------------------------------
-- R2 Financial aid packaging
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ReportingTests].[test aid packaging sums terms and separates cancelled and declined offers]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_AidAward';
    EXEC [ReportingTests].[AddAward] 1, 'PELL', 'ACCEPTED', 3000.00, 3000.00, 3000.00, '2025FA';
    EXEC [ReportingTests].[AddAward] 2, 'PELL', 'ACCEPTED', 3000.00, 2500.00, 0.00, '2026SP';
    EXEC [ReportingTests].[AddAward] 3, 'SEOG', 'CANCELLED', 400.00;
    EXEC [ReportingTests].[AddAward] 4, 'SEOG', 'DECLINED', 250.00, @TermCode = '2026SP';

    SELECT
        p.[FundCode], p.[AwardCount], p.[OfferedAmount], p.[AcceptedAmount], p.[DisbursedAmount], p.[CancelledAmount],
        p.[DeclinedAmount], p.[RemainingAmount]
    INTO #Actual
    FROM [reporting].[vw_FinancialAidPackaging] AS p;

    SELECT TOP (0)
        a.[FundCode], a.[AwardCount], a.[OfferedAmount], a.[AcceptedAmount], a.[DisbursedAmount], a.[CancelledAmount],
        a.[DeclinedAmount], a.[RemainingAmount]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected (
        [FundCode], [AwardCount], [OfferedAmount], [AcceptedAmount], [DisbursedAmount], [CancelledAmount], [DeclinedAmount],
        [RemainingAmount]
    )
    VALUES ('PELL', 2, 6000.00, 5500.00, 3000.00, 0.00, 0.00, 2500.00), ('SEOG', 2, 650.00, 0.00, 0.00, 400.00, 250.00, 0.00);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

------------------------------------------------------------------------------------------
-- R3 Student account aging
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ReportingTests].[test aging puts unpaid debits in the right bucket on every boundary day]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_AccountTransaction';
    -- As of 2026-04-30: due dates give 0, 1, 30, 31, 60, 61, 90 and 91 days past due.
    EXEC [ReportingTests].[AddTransaction] 1, 1.00, '2026-01-01', '2026-04-30';
    EXEC [ReportingTests].[AddTransaction] 2, 10.00, '2026-01-01', '2026-04-29';
    EXEC [ReportingTests].[AddTransaction] 3, 100.00, '2026-01-01', '2026-03-31';
    EXEC [ReportingTests].[AddTransaction] 4, 1000.00, '2026-01-01', '2026-03-30';
    EXEC [ReportingTests].[AddTransaction] 5, 10000.00, '2026-01-01', '2026-03-01';
    EXEC [ReportingTests].[AddTransaction] 6, 100000.00, '2026-01-01', '2026-02-28';
    EXEC [ReportingTests].[AddTransaction] 7, 1000000.00, '2026-01-01', '2026-01-30';
    EXEC [ReportingTests].[AddTransaction] 8, 10000000.00, '2026-01-01', '2026-01-29';

    SELECT
        a.[CurrentAmount], a.[Days001To030], a.[Days031To060], a.[Days061To090], a.[Days091Plus], a.[CreditBalance],
        a.[NetBalance]
    INTO #Actual
    FROM [reporting].[fn_StudentAccountAging]('2026-04-30') AS a;

    SELECT TOP (0)
        a.[CurrentAmount], a.[Days001To030], a.[Days031To060], a.[Days061To090], a.[Days091Plus], a.[CreditBalance],
        a.[NetBalance]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected (
        [CurrentAmount], [Days001To030], [Days031To060], [Days061To090], [Days091Plus], [CreditBalance], [NetBalance]
    )
    VALUES (1.00, 110.00, 11000.00, 1100000.00, 10000000.00, 0.00, 11111111.00);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ReportingTests].[test aging applies credits to the oldest due debit first]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_AccountTransaction';
    EXEC [ReportingTests].[AddTransaction] 1, 500.00, '2026-01-05', '2026-01-10';
    EXEC [ReportingTests].[AddTransaction] 2, 300.00, '2026-03-01', '2026-04-20';
    EXEC [ReportingTests].[AddTransaction] 3, -600.00, '2026-03-15', @Type = 'PAYMENT';

    SELECT a.[CurrentAmount], a.[Days001To030], a.[Days091Plus], a.[NetBalance], a.[LastPaymentDate]
    INTO #Actual
    FROM [reporting].[fn_StudentAccountAging]('2026-04-30') AS a;

    SELECT TOP (0) a.[CurrentAmount], a.[Days001To030], a.[Days091Plus], a.[NetBalance], a.[LastPaymentDate]
    INTO #Expected
    FROM #Actual AS a;
    -- The payment clears the January charge (500) and 100 of the April charge, leaving 200 that is 10 days past due.
    INSERT INTO #Expected ([CurrentAmount], [Days001To030], [Days091Plus], [NetBalance], [LastPaymentDate])
    VALUES (0.00, 200.00, 0.00, 200.00, '2026-03-15');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ReportingTests].[test aging reports an overpayment as a credit balance and ignores later postings]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_AccountTransaction';
    EXEC [ReportingTests].[AddTransaction] 1, 400.00, '2026-01-05', '2026-01-10';
    EXEC [ReportingTests].[AddTransaction] 2, -450.00, '2026-02-01', @Type = 'AID_CREDIT';
    EXEC [ReportingTests].[AddTransaction] 3, 900.00, '2026-05-01', '2026-05-15';

    SELECT a.[CurrentAmount], a.[Days091Plus], a.[CreditBalance], a.[NetBalance], a.[TransactionCount]
    INTO #Actual
    FROM [reporting].[fn_StudentAccountAging]('2026-04-30') AS a;

    SELECT TOP (0) a.[CurrentAmount], a.[Days091Plus], a.[CreditBalance], a.[NetBalance], a.[TransactionCount]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected ([CurrentAmount], [Days091Plus], [CreditBalance], [NetBalance], [TransactionCount])
    VALUES (0.00, 0.00, 50.00, -50.00, 2);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

------------------------------------------------------------------------------------------
-- R4 Academic progress
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ReportingTests].[test progress counts D as earned and keeps W and I out of the GPA]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Enrollment';
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Student';
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Credential';
    EXEC [ReportingTests].[AddProgressContext];
    EXEC [ReportingTests].[AddGrade] 1, '2025FA', 3.0, 'A', 4.00;
    EXEC [ReportingTests].[AddGrade] 2, '2025FA', 3.0, 'D', 1.00;
    EXEC [ReportingTests].[AddGrade] 3, '2025FA', 3.0, 'F', 0.00;
    EXEC [ReportingTests].[AddGrade] 4, '2025FA', 3.0, 'W', NULL, 'WITHDRAWN';
    EXEC [ReportingTests].[AddGrade] 5, '2025FA', 4.0, 'I', NULL;
    EXEC [ReportingTests].[AddGrade] 6, '2025FA', 3.0, NULL, NULL, 'DROPPED';

    SELECT a.[AttemptedCredits], a.[EarnedCredits], a.[GpaCredits], a.[TermGpa], a.[AcademicStanding]
    INTO #Actual
    FROM [reporting].[vw_AcademicProgress] AS a;

    SELECT TOP (0) a.[AttemptedCredits], a.[EarnedCredits], a.[GpaCredits], a.[TermGpa], a.[AcademicStanding]
    INTO #Expected
    FROM #Actual AS a;
    -- Attempted excludes the dropped section; GPA = (12 + 3 + 0) / 9 = 1.67.
    INSERT INTO #Expected ([AttemptedCredits], [EarnedCredits], [GpaCredits], [TermGpa], [AcademicStanding])
    VALUES (16.0, 6.0, 9.0, 1.67, 'ACADEMIC_PROBATION');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ReportingTests].[test progress accumulates across terms and marks completion and the credential]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Enrollment';
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Student';
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Credential';
    EXEC [ReportingTests].[AddProgressContext];
    EXEC [ReportingTests].[AddGrade] 1, '2025FA', 15.0, 'C', 2.00;
    EXEC [ReportingTests].[AddGrade] 2, '2026SP', 15.0, 'B', 3.00;
    EXEC [ReportingTests].[AddGrade] 3, '2026SU', 3.0, 'W', NULL, 'WITHDRAWN';
    EXEC [ReportingTests].[AddCredential] @TermCode = '2026SP';

    SELECT
        a.[TermCode], a.[CumulativeEarnedCredits], a.[CumulativeGpa], a.[AcademicStanding], a.[IsCompletionEligible],
        a.[HasCredential]
    INTO #Actual
    FROM [reporting].[vw_AcademicProgress] AS a;

    SELECT TOP (0)
        a.[TermCode], a.[CumulativeEarnedCredits], a.[CumulativeGpa], a.[AcademicStanding], a.[IsCompletionEligible],
        a.[HasCredential]
    INTO #Expected
    FROM #Actual AS a;
    -- Welding needs 30 credits. A 2.00 cumulative GPA is good standing (boundary is inclusive).
    INSERT INTO #Expected (
        [TermCode], [CumulativeEarnedCredits], [CumulativeGpa], [AcademicStanding], [IsCompletionEligible], [HasCredential]
    )
    VALUES
        ('2025FA', 15.0, 2.00, 'GOOD_STANDING', 0, 0),
        ('2026SP', 30.0, 2.50, 'GOOD_STANDING', 1, 1),
        ('2026SU', 30.0, 2.50, 'GOOD_STANDING', 1, 1);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ReportingTests].[test progress is not evaluated without GPA credits]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Enrollment';
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Student';
    EXEC tSQLt.FakeTable @TableName = N'core.vw_Credential';
    EXEC [ReportingTests].[AddProgressContext];
    EXEC [ReportingTests].[AddGrade] 1, '2026FA', 3.0, NULL, NULL;

    SELECT a.[TermGpa], a.[AcademicStanding], a.[GradesPending] INTO #Actual FROM [reporting].[vw_AcademicProgress] AS a;
    SELECT TOP (0) a.[TermGpa], a.[AcademicStanding], a.[GradesPending] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([TermGpa], [AcademicStanding], [GradesPending]) VALUES (NULL, 'NOT_EVALUATED', 1);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

------------------------------------------------------------------------------------------
-- R5 Exception worklist and drill-through
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ReportingTests].[test the masked worklist never shows a full name, birth date or email]
AS
BEGIN
    -- Runs against the deployed data: no masked column may contain a full standardized value.
    SELECT w.[ExceptionId]
    INTO #Leaks
    FROM [reporting].[vw_ExceptionWorklist] AS w
    INNER JOIN [core].[vw_Application] AS a ON w.[ApplicationId] = a.[ApplicationId]
    WHERE (LEN(a.[LastNameStd]) > 1 AND w.[ApplicantInitials] LIKE CONCAT('%', a.[LastNameStd], '%'))
       OR (a.[EmailStd] IS NOT NULL AND w.[MaskedEmail] = a.[EmailStd]);

    EXEC tSQLt.AssertEmptyTable @TableName = N'#Leaks';
END;
GO

CREATE PROCEDURE [ReportingTests].[test drill-through without a reason is refused and still audited]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'audit.AccessEvent', @Identity = 1, @Defaults = 1;
    DECLARE @Error INT;

    BEGIN TRY
        EXEC [reporting].[usp_GetExceptionDetail] @ExceptionId = 1, @AccessReason = N'  ';
    END TRY
    BEGIN CATCH
        SET @Error = ERROR_NUMBER();
    END CATCH;

    SELECT e.[EventType], e.[IsAllowed], e.[SubjectKey] INTO #Actual FROM [audit].[AccessEvent] AS e;
    SELECT TOP (0) a.[EventType], a.[IsAllowed], a.[SubjectKey] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([EventType], [IsAllowed], [SubjectKey]) VALUES ('EXCEPTION_DRILLTHROUGH', 0, '1');

    EXEC tSQLt.AssertEquals @Expected = 52204, @Actual = @Error;
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ReportingTests].[test drill-through records the reason before returning detail]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'audit.AccessEvent', @Identity = 1, @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'integration.IntegrationException';
    INSERT INTO [integration].[IntegrationException] ([ExceptionId], [ApplicationId])
    VALUES (77, 'B0000000-0000-4000-8000-000000000077');

    EXEC [reporting].[usp_GetExceptionDetail] @ExceptionId = 77, @AccessReason = N'Ticket DO-1234: resolve duplicate';

    SELECT e.[IsAllowed], e.[SubjectKey], e.[Detail] INTO #Actual FROM [audit].[AccessEvent] AS e;
    SELECT TOP (0) a.[IsAllowed], a.[SubjectKey], a.[Detail] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([IsAllowed], [SubjectKey], [Detail]) VALUES (1, '77', N'Ticket DO-1234: resolve duplicate');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

------------------------------------------------------------------------------------------
-- R6 Leadership KPIs and grains of every report
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ReportingTests].[test census KPIs say NO_SNAPSHOT instead of using live data]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusSnapshot';

    SELECT DISTINCT k.[MeasureValue], k.[DataStatus]
    INTO #Actual
    FROM [reporting].[vw_LeadershipKPI] AS k
    WHERE k.[MeasureCode] = 'CENSUS_HEADCOUNT';

    SELECT TOP (0) a.[MeasureValue], a.[DataStatus] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([MeasureValue], [DataStatus]) VALUES (NULL, 'NO_SNAPSHOT');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ReportingTests].[test every KPI measure is registered and every row is unique]
AS
BEGIN
    -- Runs against the deployed data and measure registry.
    DECLARE @Terms INT = (SELECT COUNT(*) FROM [reference].[AcademicTerm]);
    DECLARE @Measures INT = (SELECT COUNT(*) FROM [compliance].[MeasureDefinition]);
    DECLARE @Rows INT = (SELECT COUNT(*) FROM [reporting].[vw_LeadershipKPI]);
    DECLARE @Distinct INT = (
        SELECT COUNT(*) FROM (SELECT DISTINCT k.[TermCode], k.[MeasureCode] FROM [reporting].[vw_LeadershipKPI] AS k) AS d
    );
    DECLARE @Expected INT = @Terms * @Measures;

    EXEC tSQLt.AssertEquals @Expected = @Expected, @Actual = @Rows;
    EXEC tSQLt.AssertEquals @Expected = @Rows, @Actual = @Distinct;
END;
GO

CREATE PROCEDURE [ReportingTests].[test every report has exactly one row per declared grain]
AS
BEGIN
    -- Runs against the deployed data. A duplicated grain key in any report fails this test.
    CREATE TABLE #Duplicate ([Report] VARCHAR (40) NOT NULL, [GrainKey] VARCHAR (100) NOT NULL);

    INSERT INTO #Duplicate ([Report], [GrainKey])
    SELECT 'ENROLLMENT_CENSUS' AS [Report], CONCAT(c.[TermCode], '|', c.[IdNumber]) AS [GrainKey]
    FROM [reporting].[vw_EnrollmentCensus] AS c
    GROUP BY c.[TermCode], c.[IdNumber]
    HAVING COUNT(*) > 1;

    INSERT INTO #Duplicate ([Report], [GrainKey])
    SELECT 'AID_PACKAGING' AS [Report], CONCAT(p.[IdNumber], '|', p.[AidYear], '|', p.[FundCode]) AS [GrainKey]
    FROM [reporting].[vw_FinancialAidPackaging] AS p
    GROUP BY p.[IdNumber], p.[AidYear], p.[FundCode]
    HAVING COUNT(*) > 1;

    INSERT INTO #Duplicate ([Report], [GrainKey])
    SELECT 'ACCOUNT_AGING' AS [Report], CONVERT(VARCHAR (100), a.[IdNumber]) AS [GrainKey]
    FROM [reporting].[vw_StudentAccountAging] AS a
    GROUP BY a.[IdNumber]
    HAVING COUNT(*) > 1;

    INSERT INTO #Duplicate ([Report], [GrainKey])
    SELECT 'ACADEMIC_PROGRESS' AS [Report], CONCAT(a.[IdNumber], '|', a.[TermCode]) AS [GrainKey]
    FROM [reporting].[vw_AcademicProgress] AS a
    GROUP BY a.[IdNumber], a.[TermCode]
    HAVING COUNT(*) > 1;

    INSERT INTO #Duplicate ([Report], [GrainKey])
    SELECT 'EXCEPTION_WORKLIST' AS [Report], CONVERT(VARCHAR (100), w.[ExceptionId]) AS [GrainKey]
    FROM [reporting].[vw_ExceptionWorklist] AS w
    GROUP BY w.[ExceptionId]
    HAVING COUNT(*) > 1;

    EXEC tSQLt.AssertEmptyTable @TableName = N'#Duplicate';
END;
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'core';
GO
