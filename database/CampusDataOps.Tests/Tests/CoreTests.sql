/*
tSQLt tests for the conformed core views: census-day boundaries, entry status, age at census,
the July-June reporting year and the governed aging buckets.
*/
EXEC tSQLt.NewTestClass @ClassName = N'CoreTests';
GO

CREATE PROCEDURE [CoreTests].[SetUp]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'staging.Enrollment';
    EXEC tSQLt.FakeTable @TableName = N'staging.Person';
    EXEC tSQLt.FakeTable @TableName = N'reference.AcademicTerm';

    INSERT INTO [reference].[AcademicTerm] ([TermCode], [TermType], [AcademicYear], [StartDate], [CensusDate], [EndDate])
    VALUES
        ('2026SU', 'SUMMER', '2025-2026', '2026-06-01', '2026-06-08', '2026-08-07'),
        ('2026FA', 'FALL', '2026-2027', '2026-09-02', '2026-09-16', '2026-12-19'),
        ('2027SP', 'SPRING', '2026-2027', '2027-01-20', '2027-02-03', '2027-05-15');
END;
GO

CREATE PROCEDURE [CoreTests].[AddEnrollment]
    @EnrollmentId BIGINT,
    @Status       VARCHAR (15),
    @RegisteredAt DATETIME2 (3),
    @ChangedAt    DATETIME2 (3),
    @Credits      DECIMAL (4, 1) = 3.0,
    @IdNumber     INT            = 2400001,
    @TermCode     VARCHAR (10)   = '2026FA'
AS
BEGIN
    INSERT INTO [staging].[Enrollment] (
        [EnrollmentId], [IdNumber], [TermCode], [CreditHours], [RegistrationStatus], [RegisteredAtUtc], [StatusChangedAtUtc]
    )
    VALUES (@EnrollmentId, @IdNumber, @TermCode, @Credits, @Status, @RegisteredAt, @ChangedAt);
END;
GO

CREATE PROCEDURE [CoreTests].[test census counting uses the end of the census date]
AS
BEGIN
    -- Census date 2026-09-16: the boundary is 2026-09-17T00:00:00.
    EXEC [CoreTests].[AddEnrollment] 1, 'REGISTERED', '2026-09-16T23:59:59.997', '2026-09-16T23:59:59.997';
    EXEC [CoreTests].[AddEnrollment] 2, 'REGISTERED', '2026-09-17T00:00:00', '2026-09-17T00:00:00';
    EXEC [CoreTests].[AddEnrollment] 3, 'DROPPED', '2026-08-01T00:00:00', '2026-09-16T23:59:59.997';
    EXEC [CoreTests].[AddEnrollment] 4, 'DROPPED', '2026-08-01T00:00:00', '2026-09-17T00:00:00';
    EXEC [CoreTests].[AddEnrollment] 5, 'WITHDRAWN', '2026-08-01T00:00:00', '2026-10-20T00:00:00';

    SELECT e.[EnrollmentId], e.[IsCountedAtCensus], e.[IsRegisteredByCensus], e.[IsAttempted]
    INTO #Actual
    FROM [core].[vw_Enrollment] AS e;

    SELECT TOP (0) a.[EnrollmentId], a.[IsCountedAtCensus], a.[IsRegisteredByCensus], a.[IsAttempted] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([EnrollmentId], [IsCountedAtCensus], [IsRegisteredByCensus], [IsAttempted])
    VALUES (1, 1, 1, 1), (2, 0, 0, 1), (3, 0, 1, 0), (4, 1, 1, 0), (5, 1, 1, 1);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [CoreTests].[test summer starters are entering in the following fall only]
AS
BEGIN
    INSERT INTO [staging].[Person] ([IdNumber], [HasStudentRecord], [StudentEntryTermCode], [StudentProgramCode], [BirthDate])
    VALUES
        (2400001, 1, '2026SU', 'CIS.AS', '2000-01-01'),
        (2400002, 1, '2026FA', 'CIS.AS', '2000-01-01');
    EXEC [CoreTests].[AddEnrollment] 1, 'REGISTERED', '2026-08-01', '2026-08-01', @IdNumber = 2400001;
    EXEC [CoreTests].[AddEnrollment] 2, 'REGISTERED', '2026-12-01', '2026-12-01', @IdNumber = 2400001, @TermCode = '2027SP';
    EXEC [CoreTests].[AddEnrollment] 3, 'REGISTERED', '2026-08-01', '2026-08-01', @IdNumber = 2400002;
    EXEC [CoreTests].[AddEnrollment] 4, 'REGISTERED', '2026-12-01', '2026-12-01', @IdNumber = 2400002, @TermCode = '2027SP';

    SELECT c.[IdNumber], c.[TermCode], c.[EntryStatus] INTO #Actual FROM [core].[vw_StudentTermCensus] AS c;
    SELECT TOP (0) a.[IdNumber], a.[TermCode], a.[EntryStatus] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([IdNumber], [TermCode], [EntryStatus])
    VALUES
        (2400001, '2026FA', 'ENTERING'), (2400001, '2027SP', 'CONTINUING'),
        (2400002, '2026FA', 'ENTERING'), (2400002, '2027SP', 'CONTINUING');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [CoreTests].[test age at census turns over on the birthday]
AS
BEGIN
    INSERT INTO [staging].[Person] ([IdNumber], [HasStudentRecord], [StudentEntryTermCode], [BirthDate])
    VALUES (2400001, 1, '2026FA', '2006-09-16'), (2400002, 1, '2026FA', '2006-09-17'), (2400003, 1, '2026FA', '2008-02-29');
    EXEC [CoreTests].[AddEnrollment] 1, 'REGISTERED', '2026-08-01', '2026-08-01', @IdNumber = 2400001;
    EXEC [CoreTests].[AddEnrollment] 2, 'REGISTERED', '2026-08-01', '2026-08-01', @IdNumber = 2400002;
    EXEC [CoreTests].[AddEnrollment] 3, 'REGISTERED', '2026-08-01', '2026-08-01', @IdNumber = 2400003;

    SELECT c.[IdNumber], c.[AgeAtCensus] INTO #Actual FROM [core].[vw_StudentTermCensus] AS c;
    SELECT TOP (0) a.[IdNumber], a.[AgeAtCensus] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([IdNumber], [AgeAtCensus]) VALUES (2400001, 20), (2400002, 19), (2400003, 18);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [CoreTests].[test an enrollment without a student record stays in the population]
AS
BEGIN
    EXEC [CoreTests].[AddEnrollment] 1, 'REGISTERED', '2026-08-01', '2026-08-01', @IdNumber = 2499999;

    SELECT c.[IdNumber], c.[HasStudentRecord], c.[EntryStatus], c.[CensusCredits] INTO #Actual FROM [core].[vw_StudentTermCensus] AS c;
    SELECT TOP (0) a.[IdNumber], a.[HasStudentRecord], a.[EntryStatus], a.[CensusCredits] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([IdNumber], [HasStudentRecord], [EntryStatus], [CensusCredits]) VALUES (2499999, 0, NULL, 3.0);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [CoreTests].[test credentials fall in the July to June reporting year]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'staging.CredentialAwarded';
    INSERT INTO [staging].[CredentialAwarded] ([CredentialAwardedId], [ProgramCode], [AwardedDate])
    VALUES (1, 'CIS.AS', '2025-06-30'), (2, 'CIS.AS', '2025-07-01'), (3, 'CIS.AS', '2026-06-30');

    SELECT c.[CredentialAwardedId], c.[ReportingYear] INTO #Actual FROM [core].[vw_Credential] AS c;
    SELECT TOP (0) a.[CredentialAwardedId], a.[ReportingYear] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([CredentialAwardedId], [ReportingYear])
    VALUES (1, '2024-2025'), (2, '2025-2026'), (3, '2025-2026');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [CoreTests].[test aging buckets cover every day exactly once]
AS
BEGIN
    -- Days past due from -400 to 400 must each fall in exactly one governed bucket.
    WITH [Day] AS (
        SELECT TOP (801) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 401 AS [DaysPastDue]
        FROM sys.all_objects
    )

    SELECT d.[DaysPastDue], COUNT(b.[BucketCode]) AS [Buckets]
    INTO #Coverage
    FROM [Day] AS d
    LEFT JOIN [reference].[AgingBucket] AS b
        ON (b.[MinDaysPastDue] IS NULL OR d.[DaysPastDue] >= b.[MinDaysPastDue])
       AND (b.[MaxDaysPastDue] IS NULL OR d.[DaysPastDue] <= b.[MaxDaysPastDue])
    GROUP BY d.[DaysPastDue];

    DECLARE @Bad INT = (SELECT COUNT(*) FROM #Coverage AS c WHERE c.[Buckets] <> 1);
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Bad;
END;
GO
