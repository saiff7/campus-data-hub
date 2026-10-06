/*
Reference seed for Part 3 reporting (docs/specifications/report-catalog.md and
ipeds-measure-mapping.md). Same contract as reference_seed.sql: idempotent, inserts missing rows,
updates rows whose governed values differ, never deletes. Runs after reference_seed.sql.
The program catalog must agree with J1Sim.AcademicProgram and the generator's PROGRAMS
(tests/python/test_reference_alignment.py, ReportingReferenceTests).
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Change detection uses WHERE EXISTS (SELECT s.cols EXCEPT SELECT t.cols): a NULL-safe
-- comparison through correlated outer references, which SQLFluff RF01 cannot resolve.
-- noqa: disable=RF01

BEGIN TRANSACTION;

DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

------------------------------------------------------------------------------------------
DECLARE @Department TABLE (
    [DepartmentCode] VARCHAR (30)   NOT NULL,
    [DepartmentName] NVARCHAR (100) NOT NULL,
    PRIMARY KEY ([DepartmentCode])
);

INSERT INTO @Department ([DepartmentCode], [DepartmentName])
VALUES
    ('ACADEMIC_AFFAIRS', N'Academic Affairs'),
    ('ADMISSIONS', N'Admissions'),
    ('DATA_OPERATIONS', N'Data Operations'),
    ('FINANCIAL_AID', N'Financial Aid'),
    ('INSTITUTIONAL_RESEARCH', N'Institutional Research'),
    ('IT_IDENTITY', N'IT Identity Services'),
    ('REGISTRAR', N'Registrar'),
    ('STUDENT_ACCOUNTS', N'Student Accounts');

UPDATE t
SET t.[DepartmentName] = s.[DepartmentName],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[Department] AS t
INNER JOIN @Department AS s ON t.[DepartmentCode] = s.[DepartmentCode]
WHERE EXISTS (
    SELECT s.[DepartmentName]
    EXCEPT
    SELECT t.[DepartmentName]
);

INSERT INTO [reference].[Department] ([DepartmentCode], [DepartmentName])
SELECT s.[DepartmentCode], s.[DepartmentName]
FROM @Department AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[Department] AS t WHERE t.[DepartmentCode] = s.[DepartmentCode]);

------------------------------------------------------------------------------------------
DECLARE @AcademicDivision TABLE (
    [DivisionCode] VARCHAR (30)   NOT NULL,
    [DivisionName] NVARCHAR (100) NOT NULL,
    PRIMARY KEY ([DivisionCode])
);

INSERT INTO @AcademicDivision ([DivisionCode], [DivisionName])
VALUES
    ('BUSINESS_TECHNOLOGY', N'Business and Technology'),
    ('HEALTH_SCIENCES', N'Health Sciences'),
    ('HUMAN_SERVICES', N'Human Services'),
    ('LIBERAL_ARTS', N'Liberal Arts'),
    ('TRADES', N'Trades and Technical Careers');

UPDATE t
SET t.[DivisionName] = s.[DivisionName],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[AcademicDivision] AS t
INNER JOIN @AcademicDivision AS s ON t.[DivisionCode] = s.[DivisionCode]
WHERE EXISTS (
    SELECT s.[DivisionName]
    EXCEPT
    SELECT t.[DivisionName]
);

INSERT INTO [reference].[AcademicDivision] ([DivisionCode], [DivisionName])
SELECT s.[DivisionCode], s.[DivisionName]
FROM @AcademicDivision AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[AcademicDivision] AS t WHERE t.[DivisionCode] = s.[DivisionCode]);

------------------------------------------------------------------------------------------
DECLARE @AcademicProgram TABLE (
    [ProgramCode]     VARCHAR (20)   NOT NULL,
    [ProgramName]     NVARCHAR (150) NOT NULL,
    [CredentialLevel] VARCHAR (20)   NOT NULL,
    [CipCode]         CHAR (7)       NOT NULL,
    [RequiredCredits] DECIMAL (5, 1) NOT NULL,
    [IpedsAwardLevel] VARCHAR (3)    NOT NULL,
    [DivisionCode]    VARCHAR (30)   NOT NULL,
    [IsActive]        BIT            NOT NULL,
    PRIMARY KEY ([ProgramCode])
);

INSERT INTO @AcademicProgram ([ProgramCode], [ProgramName], [CredentialLevel], [CipCode], [RequiredCredits],
    [IpedsAwardLevel], [DivisionCode], [IsActive])
VALUES
    ('ACCT.AS', N'Accounting', 'ASSOCIATE', '52.0301', 60.0, '3', 'BUSINESS_TECHNOLOGY', 1),
    ('BUS.AS', N'Business Administration', 'ASSOCIATE', '52.0201', 60.0, '3', 'BUSINESS_TECHNOLOGY', 1),
    ('CIS.AS', N'Computer Information Systems', 'ASSOCIATE', '11.0101', 60.0, '3', 'BUSINESS_TECHNOLOGY', 1),
    ('NURS.AS', N'Nursing', 'ASSOCIATE', '51.3801', 70.0, '3', 'HEALTH_SCIENCES', 1),
    ('LIBA.AS', N'Liberal Arts', 'ASSOCIATE', '24.0101', 60.0, '3', 'LIBERAL_ARTS', 1),
    ('CJ.AS', N'Criminal Justice', 'ASSOCIATE', '43.0104', 60.0, '3', 'HUMAN_SERVICES', 1),
    ('ECE.CERT', N'Early Childhood Education', 'CERTIFICATE', '19.0709', 30.0, '2', 'HUMAN_SERVICES', 1),
    ('WELD.CERT', N'Welding Technology', 'CERTIFICATE', '48.0508', 30.0, '2', 'TRADES', 1),
    ('MEDA.CERT', N'Medical Assisting', 'CERTIFICATE', '51.0801', 30.0, '2', 'HEALTH_SCIENCES', 0);

UPDATE t
SET t.[ProgramName] = s.[ProgramName],
    t.[CredentialLevel] = s.[CredentialLevel],
    t.[CipCode] = s.[CipCode],
    t.[RequiredCredits] = s.[RequiredCredits],
    t.[IpedsAwardLevel] = s.[IpedsAwardLevel],
    t.[DivisionCode] = s.[DivisionCode],
    t.[IsActive] = s.[IsActive],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[AcademicProgram] AS t
INNER JOIN @AcademicProgram AS s ON t.[ProgramCode] = s.[ProgramCode]
WHERE EXISTS (
    SELECT s.[ProgramName], s.[CredentialLevel], s.[CipCode], s.[RequiredCredits], s.[IpedsAwardLevel],
        s.[DivisionCode], s.[IsActive]
    EXCEPT
    SELECT t.[ProgramName], t.[CredentialLevel], t.[CipCode], t.[RequiredCredits], t.[IpedsAwardLevel],
        t.[DivisionCode], t.[IsActive]
);

INSERT INTO [reference].[AcademicProgram] ([ProgramCode], [ProgramName], [CredentialLevel], [CipCode],
    [RequiredCredits], [IpedsAwardLevel], [DivisionCode], [IsActive])
SELECT s.[ProgramCode], s.[ProgramName], s.[CredentialLevel], s.[CipCode], s.[RequiredCredits], s.[IpedsAwardLevel],
    s.[DivisionCode], s.[IsActive]
FROM @AcademicProgram AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[AcademicProgram] AS t WHERE t.[ProgramCode] = s.[ProgramCode]);

------------------------------------------------------------------------------------------
DECLARE @AidFund TABLE (
    [FundCode]             VARCHAR (15)   NOT NULL,
    [FundName]             NVARCHAR (100) NOT NULL,
    [FundSource]           VARCHAR (15)   NOT NULL,
    [FundType]             VARCHAR (10)   NOT NULL,
    [IsPell]               BIT            NOT NULL,
    [IsFederalStudentLoan] BIT            NOT NULL,
    PRIMARY KEY ([FundCode])
);

INSERT INTO @AidFund ([FundCode], [FundName], [FundSource], [FundType], [IsPell], [IsFederalStudentLoan])
VALUES
    ('PELL', N'Federal Pell Grant', 'FEDERAL', 'GRANT', 1, 0),
    ('SEOG', N'Federal Supplemental Educational Opportunity Grant', 'FEDERAL', 'GRANT', 0, 0),
    ('DIRECT_SUB', N'Federal Direct Subsidized Loan', 'FEDERAL', 'LOAN', 0, 1),
    ('DIRECT_UNSUB', N'Federal Direct Unsubsidized Loan', 'FEDERAL', 'LOAN', 0, 1),
    ('MASSGRANT', N'MASSGrant (state)', 'STATE', 'GRANT', 0, 0),
    ('INST_SCHOL', N'Institutional scholarship', 'INSTITUTIONAL', 'GRANT', 0, 0);

UPDATE t
SET t.[FundName] = s.[FundName],
    t.[FundSource] = s.[FundSource],
    t.[FundType] = s.[FundType],
    t.[IsPell] = s.[IsPell],
    t.[IsFederalStudentLoan] = s.[IsFederalStudentLoan],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[AidFund] AS t
INNER JOIN @AidFund AS s ON t.[FundCode] = s.[FundCode]
WHERE EXISTS (
    SELECT s.[FundName], s.[FundSource], s.[FundType], s.[IsPell], s.[IsFederalStudentLoan]
    EXCEPT
    SELECT t.[FundName], t.[FundSource], t.[FundType], t.[IsPell], t.[IsFederalStudentLoan]
);

INSERT INTO [reference].[AidFund] ([FundCode], [FundName], [FundSource], [FundType], [IsPell], [IsFederalStudentLoan])
SELECT s.[FundCode], s.[FundName], s.[FundSource], s.[FundType], s.[IsPell], s.[IsFederalStudentLoan]
FROM @AidFund AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[AidFund] AS t WHERE t.[FundCode] = s.[FundCode]);

------------------------------------------------------------------------------------------
DECLARE @AgingBucket TABLE (
    [BucketCode]     VARCHAR (10)  NOT NULL,
    [BucketName]     NVARCHAR (50) NOT NULL,
    [MinDaysPastDue] INT           NULL,
    [MaxDaysPastDue] INT           NULL,
    [SortOrder]      TINYINT       NOT NULL,
    PRIMARY KEY ([BucketCode])
);

INSERT INTO @AgingBucket ([BucketCode], [BucketName], [MinDaysPastDue], [MaxDaysPastDue], [SortOrder])
VALUES
    ('CURRENT', N'Current (not yet due)', NULL, 0, 1),
    ('D001_030', N'1-30 days', 1, 30, 2),
    ('D031_060', N'31-60 days', 31, 60, 3),
    ('D061_090', N'61-90 days', 61, 90, 4),
    ('D091_PLUS', N'Over 90 days', 91, NULL, 5);

UPDATE t
SET t.[BucketName] = s.[BucketName],
    t.[MinDaysPastDue] = s.[MinDaysPastDue],
    t.[MaxDaysPastDue] = s.[MaxDaysPastDue],
    t.[SortOrder] = s.[SortOrder],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[AgingBucket] AS t
INNER JOIN @AgingBucket AS s ON t.[BucketCode] = s.[BucketCode]
WHERE EXISTS (
    SELECT s.[BucketName], s.[MinDaysPastDue], s.[MaxDaysPastDue], s.[SortOrder]
    EXCEPT
    SELECT t.[BucketName], t.[MinDaysPastDue], t.[MaxDaysPastDue], t.[SortOrder]
);

INSERT INTO [reference].[AgingBucket] ([BucketCode], [BucketName], [MinDaysPastDue], [MaxDaysPastDue], [SortOrder])
SELECT s.[BucketCode], s.[BucketName], s.[MinDaysPastDue], s.[MaxDaysPastDue], s.[SortOrder]
FROM @AgingBucket AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[AgingBucket] AS t WHERE t.[BucketCode] = s.[BucketCode]);

------------------------------------------------------------------------------------------
DECLARE @AcademicStandingRule TABLE (
    [StandingCode]              VARCHAR (20)   NOT NULL,
    [Description]               NVARCHAR (200) NOT NULL,
    [MinCumulativeGpa]          DECIMAL (3, 2) NOT NULL,
    [MaxCumulativeGpaExclusive] DECIMAL (3, 2) NULL,
    PRIMARY KEY ([StandingCode])
);

INSERT INTO @AcademicStandingRule ([StandingCode], [Description], [MinCumulativeGpa], [MaxCumulativeGpaExclusive])
VALUES
    ('GOOD_STANDING', N'Cumulative GPA of 2.00 or above.', 2.00, NULL),
    ('ACADEMIC_PROBATION', N'Cumulative GPA below 2.00.', 0.00, 2.00);

UPDATE t
SET t.[Description] = s.[Description],
    t.[MinCumulativeGpa] = s.[MinCumulativeGpa],
    t.[MaxCumulativeGpaExclusive] = s.[MaxCumulativeGpaExclusive],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[AcademicStandingRule] AS t
INNER JOIN @AcademicStandingRule AS s ON t.[StandingCode] = s.[StandingCode]
WHERE EXISTS (
    SELECT s.[Description], s.[MinCumulativeGpa], s.[MaxCumulativeGpaExclusive]
    EXCEPT
    SELECT t.[Description], t.[MinCumulativeGpa], t.[MaxCumulativeGpaExclusive]
);

INSERT INTO [reference].[AcademicStandingRule] ([StandingCode], [Description], [MinCumulativeGpa],
    [MaxCumulativeGpaExclusive])
SELECT s.[StandingCode], s.[Description], s.[MinCumulativeGpa], s.[MaxCumulativeGpaExclusive]
FROM @AcademicStandingRule AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[AcademicStandingRule] AS t WHERE t.[StandingCode] = s.[StandingCode]);

------------------------------------------------------------------------------------------
DECLARE @ExtractStatus TABLE (
    [ExtractStatusCode] VARCHAR (15)   NOT NULL,
    [Description]       NVARCHAR (200) NOT NULL,
    PRIMARY KEY ([ExtractStatusCode])
);

INSERT INTO @ExtractStatus ([ExtractStatusCode], [Description])
VALUES
    ('GENERATING', N'Rows and controls are being written.'),
    ('SUCCEEDED', N'Rows, controls and checksum are stored; the run is immutable.'),
    ('FAILED', N'The builder failed; the run records the error and has no rows.');

UPDATE t
SET t.[Description] = s.[Description],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ExtractStatus] AS t
INNER JOIN @ExtractStatus AS s ON t.[ExtractStatusCode] = s.[ExtractStatusCode]
WHERE EXISTS (
    SELECT s.[Description]
    EXCEPT
    SELECT t.[Description]
);

INSERT INTO [reference].[ExtractStatus] ([ExtractStatusCode], [Description])
SELECT s.[ExtractStatusCode], s.[Description]
FROM @ExtractStatus AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[ExtractStatus] AS t WHERE t.[ExtractStatusCode] = s.[ExtractStatusCode]);

------------------------------------------------------------------------------------------
DECLARE @ValidationStatus TABLE (
    [ValidationStatusCode] VARCHAR (15)   NOT NULL,
    [Description]          NVARCHAR (200) NOT NULL,
    PRIMARY KEY ([ValidationStatusCode])
);

INSERT INTO @ValidationStatus ([ValidationStatusCode], [Description])
VALUES
    ('PASSED', N'Every control passed.'),
    ('WARNING', N'No control failed, but at least one warned (prior-period change or an uncheckable rule).'),
    ('FAILED', N'At least one reconciliation, subtotal or rule control failed.');

UPDATE t
SET t.[Description] = s.[Description],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ValidationStatus] AS t
INNER JOIN @ValidationStatus AS s ON t.[ValidationStatusCode] = s.[ValidationStatusCode]
WHERE EXISTS (
    SELECT s.[Description]
    EXCEPT
    SELECT t.[Description]
);

INSERT INTO [reference].[ValidationStatus] ([ValidationStatusCode], [Description])
SELECT s.[ValidationStatusCode], s.[Description]
FROM @ValidationStatus AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[ValidationStatus] AS t WHERE t.[ValidationStatusCode] = s.[ValidationStatusCode]);

------------------------------------------------------------------------------------------
DECLARE @ApprovalStatus TABLE (
    [ApprovalStatusCode] VARCHAR (15)   NOT NULL,
    [Description]        NVARCHAR (200) NOT NULL,
    PRIMARY KEY ([ApprovalStatusCode])
);

INSERT INTO @ApprovalStatus ([ApprovalStatusCode], [Description])
VALUES
    ('PENDING', N'Not yet reviewed.'),
    ('APPROVED', N'Approved for release by someone other than the requester.'),
    ('REJECTED', N'Rejected by a reviewer; kept for the record.');

UPDATE t
SET t.[Description] = s.[Description],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ApprovalStatus] AS t
INNER JOIN @ApprovalStatus AS s ON t.[ApprovalStatusCode] = s.[ApprovalStatusCode]
WHERE EXISTS (
    SELECT s.[Description]
    EXCEPT
    SELECT t.[Description]
);

INSERT INTO [reference].[ApprovalStatus] ([ApprovalStatusCode], [Description])
SELECT s.[ApprovalStatusCode], s.[Description]
FROM @ApprovalStatus AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[ApprovalStatus] AS t WHERE t.[ApprovalStatusCode] = s.[ApprovalStatusCode]);

------------------------------------------------------------------------------------------
DECLARE @ExtractType TABLE (
    [ExtractTypeCode]     VARCHAR (30)   NOT NULL,
    [Description]         NVARCHAR (400) NOT NULL,
    [Grain]               NVARCHAR (200) NOT NULL,
    [OwnerDepartmentCode] VARCHAR (30)   NOT NULL,
    [SecurityClass]       VARCHAR (25)   NOT NULL,
    [PeriodType]          VARCHAR (15)   NOT NULL,
    [AccessRoleName]      NVARCHAR (128) NOT NULL,
    [IsPublicSafe]        BIT            NOT NULL,
    [IsPrivileged]        BIT            NOT NULL,
    [GeneratorVersion]    VARCHAR (10)   NOT NULL,
    PRIMARY KEY ([ExtractTypeCode])
);

INSERT INTO @ExtractType ([ExtractTypeCode], [Description], [Grain], [OwnerDepartmentCode], [SecurityClass],
    [PeriodType], [AccessRoleName], [IsPublicSafe], [IsPrivileged], [GeneratorVersion])
VALUES
    ('ENROLLMENT_CENSUS',
        N'R1 Enrollment census extract from the term''s census snapshot.',
        N'One row per student per term', 'REGISTRAR',
        'CONFIDENTIAL_STUDENT', 'TERM', N'role_enrollment_reporter', 0, 1, '1.0'),
    ('AID_PACKAGING',
        N'R2 Financial aid packaging for an aid year.',
        N'One row per student, aid year and fund', 'FINANCIAL_AID',
        'CONFIDENTIAL_STUDENT', 'ACADEMIC_YEAR', N'role_financial_aid_reporter', 0, 1, '1.0'),
    ('ACCOUNT_AGING',
        N'R3 Student account aging as of a date.',
        N'One row per student with a posted transaction', 'STUDENT_ACCOUNTS',
        'CONFIDENTIAL_STUDENT', 'AS_OF_DATE', N'role_student_accounts_reporter', 0, 1, '1.0'),
    ('ACADEMIC_PROGRESS',
        N'R4 Academic progress for a term.',
        N'One row per student per term', 'ACADEMIC_AFFAIRS',
        'CONFIDENTIAL_STUDENT', 'TERM', N'role_enrollment_reporter', 0, 1, '1.0'),
    ('EXCEPTION_WORKLIST',
        N'R5 Masked applicant integration exception worklist.',
        N'One row per active exception', 'DATA_OPERATIONS',
        'INTERNAL_MASKED', 'NONE', N'role_integration_service', 0, 0, '1.0'),
    ('LEADERSHIP_KPI',
        N'R6 Leadership KPI dataset for the terms of an academic year.',
        N'One row per term and measure', 'INSTITUTIONAL_RESEARCH',
        'INTERNAL_AGGREGATE', 'ACADEMIC_YEAR', N'role_ir_analyst', 1, 0, '1.0'),
    ('DQ_SCORECARD',
        N'Data-quality scorecard from the latest validation run.',
        N'One row per data-quality rule', 'DATA_OPERATIONS',
        'INTERNAL_AGGREGATE', 'NONE', N'role_integration_service', 1, 0, '1.0'),
    ('IPEDS_FE',
        N'Educational simulation of the IPEDS Fall Enrollment component; not an IPEDS submission.',
        N'One row per section and cell', 'INSTITUTIONAL_RESEARCH',
        'INTERNAL_AGGREGATE', 'TERM', N'role_ir_analyst', 1, 0, '1.0'),
    ('IPEDS_E12',
        N'Educational simulation of the IPEDS 12-month Enrollment component; not an IPEDS submission.',
        N'One row per section and cell', 'INSTITUTIONAL_RESEARCH',
        'INTERNAL_AGGREGATE', 'ACADEMIC_YEAR', N'role_ir_analyst', 1, 0, '1.0'),
    ('IPEDS_C',
        N'Educational simulation of the IPEDS Completions component; not an IPEDS submission.',
        N'One row per section and cell', 'INSTITUTIONAL_RESEARCH',
        'INTERNAL_AGGREGATE', 'ACADEMIC_YEAR', N'role_ir_analyst', 1, 0, '1.0'),
    ('IPEDS_SFA',
        N'Educational simulation of the IPEDS Student Financial Aid component; not an IPEDS submission.',
        N'One row per student group and aid type', 'INSTITUTIONAL_RESEARCH',
        'INTERNAL_AGGREGATE', 'ACADEMIC_YEAR', N'role_ir_analyst', 1, 0, '1.0');

UPDATE t
SET t.[Description] = s.[Description],
    t.[Grain] = s.[Grain],
    t.[OwnerDepartmentCode] = s.[OwnerDepartmentCode],
    t.[SecurityClass] = s.[SecurityClass],
    t.[PeriodType] = s.[PeriodType],
    t.[AccessRoleName] = s.[AccessRoleName],
    t.[IsPublicSafe] = s.[IsPublicSafe],
    t.[IsPrivileged] = s.[IsPrivileged],
    t.[GeneratorVersion] = s.[GeneratorVersion],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ExtractType] AS t
INNER JOIN @ExtractType AS s ON t.[ExtractTypeCode] = s.[ExtractTypeCode]
WHERE EXISTS (
    SELECT s.[Description], s.[Grain], s.[OwnerDepartmentCode], s.[SecurityClass], s.[PeriodType], s.[AccessRoleName],
        s.[IsPublicSafe], s.[IsPrivileged], s.[GeneratorVersion]
    EXCEPT
    SELECT t.[Description], t.[Grain], t.[OwnerDepartmentCode], t.[SecurityClass], t.[PeriodType], t.[AccessRoleName],
        t.[IsPublicSafe], t.[IsPrivileged], t.[GeneratorVersion]
);

INSERT INTO [reference].[ExtractType] ([ExtractTypeCode], [Description], [Grain], [OwnerDepartmentCode],
    [SecurityClass], [PeriodType], [AccessRoleName], [IsPublicSafe], [IsPrivileged], [GeneratorVersion])
SELECT s.[ExtractTypeCode], s.[Description], s.[Grain], s.[OwnerDepartmentCode], s.[SecurityClass], s.[PeriodType],
    s.[AccessRoleName], s.[IsPublicSafe], s.[IsPrivileged], s.[GeneratorVersion]
FROM @ExtractType AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[ExtractType] AS t WHERE t.[ExtractTypeCode] = s.[ExtractTypeCode]);

------------------------------------------------------------------------------------------
DECLARE @ExtractSchedule TABLE (
    [ScheduleCode]    VARCHAR (10) NOT NULL,
    [ExtractTypeCode] VARCHAR (30) NOT NULL,
    [PeriodRule]      VARCHAR (30) NOT NULL,
    [SortOrder]       TINYINT      NOT NULL,
    PRIMARY KEY ([ScheduleCode], [ExtractTypeCode])
);

INSERT INTO @ExtractSchedule ([ScheduleCode], [ExtractTypeCode], [PeriodRule], [SortOrder])
VALUES
    ('DAILY', 'ACCOUNT_AGING', 'TODAY', 1),
    ('DAILY', 'AID_PACKAGING', 'CURRENT_ACADEMIC_YEAR', 2),
    ('DAILY', 'EXCEPTION_WORKLIST', 'NONE', 3),
    ('DAILY', 'LEADERSHIP_KPI', 'CURRENT_ACADEMIC_YEAR', 4),
    ('WEEKLY', 'DQ_SCORECARD', 'NONE', 1),
    ('WEEKLY', 'ACADEMIC_PROGRESS', 'CURRENT_TERM', 2),
    ('CENSUS', 'ENROLLMENT_CENSUS', 'NEW_SNAPSHOT_TERMS', 1),
    ('CENSUS', 'IPEDS_FE', 'NEW_SNAPSHOT_FALL_TERMS', 2),
    ('CENSUS', 'IPEDS_E12', 'LAST_COMPLETED_ACADEMIC_YEAR', 3),
    ('CENSUS', 'IPEDS_C', 'LAST_COMPLETED_ACADEMIC_YEAR', 4),
    ('CENSUS', 'IPEDS_SFA', 'LAST_COMPLETED_ACADEMIC_YEAR', 5);

UPDATE t
SET t.[PeriodRule] = s.[PeriodRule],
    t.[SortOrder] = s.[SortOrder],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ExtractSchedule] AS t
INNER JOIN @ExtractSchedule AS s ON t.[ScheduleCode] = s.[ScheduleCode] AND t.[ExtractTypeCode] = s.[ExtractTypeCode]
WHERE EXISTS (
    SELECT s.[PeriodRule], s.[SortOrder]
    EXCEPT
    SELECT t.[PeriodRule], t.[SortOrder]
);

INSERT INTO [reference].[ExtractSchedule] ([ScheduleCode], [ExtractTypeCode], [PeriodRule], [SortOrder])
SELECT s.[ScheduleCode], s.[ExtractTypeCode], s.[PeriodRule], s.[SortOrder]
FROM @ExtractSchedule AS s
WHERE NOT EXISTS (
    SELECT 1 FROM [reference].[ExtractSchedule] AS t
    WHERE t.[ScheduleCode] = s.[ScheduleCode] AND t.[ExtractTypeCode] = s.[ExtractTypeCode]
);

-- noqa: enable=RF01

COMMIT TRANSACTION;
