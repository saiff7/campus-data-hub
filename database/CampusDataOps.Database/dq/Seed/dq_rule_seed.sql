/*
Data-quality rule metadata (docs/specifications/data-quality-rules.md). Idempotent: inserts
missing rules and updates governed values. IsActive is governed here too; to retire a rule,
set it to 0 in this script rather than deleting the row, because results reference it.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- noqa: disable=RF01

BEGIN TRANSACTION;

DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

DECLARE @Rule TABLE (
    [RuleCode]            VARCHAR (40)   NOT NULL PRIMARY KEY,
    [Description]         NVARCHAR (400) NOT NULL,
    [EntityName]          VARCHAR (40)   NOT NULL,
    [Severity]            VARCHAR (10)   NOT NULL,
    [OwnerDepartment]     NVARCHAR (100) NOT NULL,
    [EffectiveFrom]       DATE           NOT NULL,
    [IsActive]            BIT            NOT NULL,
    [ExpectedCondition]   NVARCHAR (400) NOT NULL,
    [RemediationGuidance] NVARCHAR (800) NOT NULL,
    [CheckProcedure]      NVARCHAR (256) NOT NULL
);

INSERT INTO @Rule (
    [RuleCode], [Description], [EntityName], [Severity], [OwnerDepartment], [EffectiveFrom], [IsActive],
    [ExpectedCondition], [RemediationGuidance], [CheckProcedure]
)
VALUES
    ('APP_REQUIRED_FIELDS', N'Eligible application has every required field.', 'APPLICATION', 'HIGH', N'Admissions',
        '2026-01-01', 1,
        N'First name, last name, birth date, entry term and first program choice are present.',
        N'Complete the missing field in Slate-Sim; the next load re-evaluates it.', N'dq.usp_CheckApplicantRules'),
    ('APP_EMAIL_FORMAT', N'Applicant email is well formed.', 'APPLICATION', 'LOW', N'Admissions',
        '2026-01-01', 1,
        N'A present email has one @, a non-empty local part and a dotted domain, with no spaces.',
        N'Correct the email in Slate-Sim.', N'dq.usp_CheckApplicantRules'),
    ('APP_PHONE_FORMAT', N'Applicant phone is a 10-digit number.', 'APPLICATION', 'LOW', N'Admissions',
        '2026-01-01', 1,
        N'A present phone normalizes to 10 digits.',
        N'Correct the phone in Slate-Sim.', N'dq.usp_CheckApplicantRules'),
    ('APP_PROGRAM_VALID', N'Eligible application names an active crosswalked program.', 'APPLICATION', 'HIGH', N'Admissions',
        '2026-01-01', 1,
        N'The first program choice is in reference.ProgramCrosswalk and active.',
        N'Correct the program in Slate-Sim, or have the Registrar update the crosswalk.', N'dq.usp_CheckApplicantRules'),
    ('APP_TERM_VALID', N'Eligible application names a known term open for admission.', 'APPLICATION', 'HIGH', N'Admissions',
        '2026-01-01', 1,
        N'The entry term is in reference.AcademicTerm with IsOpenForAdmission = 1.',
        N'Correct the entry term in Slate-Sim, or have the Registrar open the term.', N'dq.usp_CheckApplicantRules'),
    ('APP_DUPLICATE_APPLICATION', N'One eligible application per person and entry term.', 'APPLICATION', 'MEDIUM', N'Admissions',
        '2026-01-01', 1,
        N'No two eligible applications share a Slate-Sim person and entry term.',
        N'Withdraw the superseded application in Slate-Sim.', N'dq.usp_CheckApplicantRules'),
    ('SIS_DUPLICATE_PERSON', N'J1-Sim has one person record per individual.', 'SIS_PERSON', 'HIGH', N'Registrar',
        '2026-01-01', 1,
        N'No two J1-Sim people share normalized first and last name, birth date and postal code.',
        N'Review the group and merge the records under the person-merge procedure.', N'dq.usp_CheckDuplicatePeople'),
    ('ENR_STUDENT_EXISTS', N'Every enrollment belongs to a student.', 'ENROLLMENT', 'HIGH', N'Registrar',
        '2026-01-01', 1,
        N'The enrollment''s person has a staged J1-Sim student record.',
        N'Create the student record or remove the enrollment in J1-Sim.', N'dq.usp_CheckEnrollmentIntegrity'),
    ('ENR_TERM_VALID', N'Every enrollment is in a governed term.', 'ENROLLMENT', 'HIGH', N'Registrar',
        '2026-01-01', 1,
        N'The course section''s term is in reference.AcademicTerm.',
        N'Correct the section term in J1-Sim or add the term to the governed calendar.', N'dq.usp_CheckEnrollmentIntegrity'),
    ('ENR_GRADE_STATUS', N'Grades agree with registration status.', 'ENROLLMENT', 'MEDIUM', N'Registrar',
        '2026-01-01', 1,
        N'Dropped enrollments have no grade; withdrawn enrollments have no grade other than W.',
        N'Correct the grade or the registration status in J1-Sim.', N'dq.usp_CheckEnrollmentIntegrity'),
    ('AID_PERIOD_VALID', N'Aid is awarded for a valid academic period.', 'AID_AWARD', 'HIGH', N'Financial Aid',
        '2026-01-01', 1,
        N'The award term is in reference.AcademicTerm and the aid year equals the term''s academic year.',
        N'Correct the award term or aid year in J1-Sim.', N'dq.usp_CheckFinancialAidPeriods'),
    ('AID_DISBURSED_ENROLLED', N'Disbursed aid has an enrollment in its term.', 'AID_AWARD', 'MEDIUM', N'Financial Aid',
        '2026-01-01', 1,
        N'An award with a disbursed amount has a REGISTERED enrollment for the student in the award term.',
        N'Review the disbursement against enrollment; this is a consistency check, not an eligibility ruling.',
        N'dq.usp_CheckFinancialAidPeriods'),
    ('DIR_ACTIVE_STUDENT_ACCOUNT', N'Active students have an enabled directory account.', 'STUDENT', 'MEDIUM', N'IT Identity Services',
        '2026-01-01', 1,
        N'Every ACTIVE student has an enabled STUDENT account whose EmployeeId is the student''s ID number.',
        N'Provision the account from the J1-Sim record.', N'dq.usp_CheckCrossSystemConsistency'),
    ('DIR_ORPHAN_ACCOUNT', N'Student directory accounts belong to a J1-Sim person.', 'DIRECTORY_ACCOUNT', 'MEDIUM', N'IT Identity Services',
        '2026-01-01', 1,
        N'Every STUDENT account has a numeric EmployeeId that is a J1-Sim ID number.',
        N'Disable or relink the account after review.', N'dq.usp_CheckCrossSystemConsistency'),
    ('ACCT_DETAIL_TO_TOTAL', N'Staged account detail reconciles to source control totals.', 'ACCOUNT_TERM', 'HIGH', N'Student Accounts',
        '2026-01-01', 1,
        N'Staged transaction count and amount for each student-term equal the latest captured source control total.',
        N'Reload J1-Sim; if the difference persists, investigate source deletions or a load defect.',
        N'dq.usp_CheckAccountControlTotals'),
    ('INT_CROSSWALK_PRESENT', N'Integrated applications have a source crosswalk.', 'APPLICATION', 'HIGH', N'Data Operations',
        '2026-01-01', 1,
        N'Every application written to J1-Sim has an integration.SourceCrosswalk row for its Slate-Sim person.',
        N'Investigate the outbound write; the crosswalk is written in the same transaction.',
        N'dq.usp_CheckCrossSystemConsistency');

UPDATE t
SET t.[Description] = s.[Description],
    t.[EntityName] = s.[EntityName],
    t.[Severity] = s.[Severity],
    t.[OwnerDepartment] = s.[OwnerDepartment],
    t.[EffectiveFrom] = s.[EffectiveFrom],
    t.[IsActive] = s.[IsActive],
    t.[ExpectedCondition] = s.[ExpectedCondition],
    t.[RemediationGuidance] = s.[RemediationGuidance],
    t.[CheckProcedure] = s.[CheckProcedure],
    t.[UpdatedAtUtc] = @NowUtc
FROM [dq].[Rule] AS t
INNER JOIN @Rule AS s ON t.[RuleCode] = s.[RuleCode]
WHERE EXISTS (
    SELECT
        s.[Description], s.[EntityName], s.[Severity], s.[OwnerDepartment], s.[EffectiveFrom], s.[IsActive],
        s.[ExpectedCondition], s.[RemediationGuidance], s.[CheckProcedure]
    EXCEPT
    SELECT
        t.[Description], t.[EntityName], t.[Severity], t.[OwnerDepartment], t.[EffectiveFrom], t.[IsActive],
        t.[ExpectedCondition], t.[RemediationGuidance], t.[CheckProcedure]
);

INSERT INTO [dq].[Rule] (
    [RuleCode], [Description], [EntityName], [Severity], [OwnerDepartment], [EffectiveFrom], [IsActive],
    [ExpectedCondition], [RemediationGuidance], [CheckProcedure]
)
SELECT
    s.[RuleCode], s.[Description], s.[EntityName], s.[Severity], s.[OwnerDepartment], s.[EffectiveFrom], s.[IsActive],
    s.[ExpectedCondition], s.[RemediationGuidance], s.[CheckProcedure]
FROM @Rule AS s
WHERE NOT EXISTS (SELECT 1 FROM [dq].[Rule] AS t WHERE t.[RuleCode] = s.[RuleCode]);

-- noqa: enable=RF01

COMMIT TRANSACTION;
