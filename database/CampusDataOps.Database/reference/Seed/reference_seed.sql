/*
Reference seed. Idempotent: inserts missing rows and updates rows whose governed values
differ. Rows removed from this script are not deleted, because audit history may still
reference them; retire them by setting IsActive = 0 here instead.
The term calendar and program list must match pipelines/campus_ops/generators/academics.py.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Change detection uses WHERE EXISTS (SELECT s.cols EXCEPT SELECT t.cols): a NULL-safe
-- comparison through correlated outer references, which SQLFluff RF01 cannot resolve.
-- noqa: disable=RF01

BEGIN TRANSACTION;

DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

------------------------------------------------------------------------------------------
DECLARE @SourceSystem TABLE (
    [SourceSystemCode] VARCHAR (20)   NOT NULL PRIMARY KEY,
    [SourceSystemName] NVARCHAR (100) NOT NULL,
    [Description]      NVARCHAR (400) NOT NULL,
    [IsActive]         BIT            NOT NULL
);

INSERT INTO @SourceSystem ([SourceSystemCode], [SourceSystemName], [Description], [IsActive])
VALUES
    ('SLATE_SIM', N'Slate-Sim', N'Simulated admissions CRM: prospects, applicants, applications and exports.', 1),
    ('J1_SIM', N'J1-Sim', N'Simulated student information system: people, students, terms, enrollment, aid and accounts.', 1),
    ('DIRECTORY_SIM', N'Directory-Sim', N'Simulated identity directory: accounts, group membership and status history.', 1);

UPDATE t
SET t.[SourceSystemName] = s.[SourceSystemName],
    t.[Description] = s.[Description],
    t.[IsActive] = s.[IsActive],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[SourceSystem] AS t
INNER JOIN @SourceSystem AS s ON t.[SourceSystemCode] = s.[SourceSystemCode]
WHERE EXISTS (
    SELECT s.[SourceSystemName], s.[Description], s.[IsActive]
    EXCEPT
    SELECT t.[SourceSystemName], t.[Description], t.[IsActive]
);

INSERT INTO [reference].[SourceSystem] ([SourceSystemCode], [SourceSystemName], [Description], [IsActive])
SELECT s.[SourceSystemCode], s.[SourceSystemName], s.[Description], s.[IsActive]
FROM @SourceSystem AS s
WHERE NOT EXISTS (
    SELECT 1 FROM [reference].[SourceSystem] AS t WHERE t.[SourceSystemCode] = s.[SourceSystemCode]
);

------------------------------------------------------------------------------------------
DECLARE @BatchStatus TABLE (
    [BatchStatusCode] VARCHAR (20)   NOT NULL PRIMARY KEY,
    [Description]     NVARCHAR (200) NOT NULL,
    [IsTerminal]      BIT            NOT NULL
);

INSERT INTO @BatchStatus ([BatchStatusCode], [Description], [IsTerminal])
VALUES
    ('RUNNING', N'Batch has started and has not finished.', 0),
    ('SUCCEEDED', N'Batch finished and its control totals balanced.', 1),
    ('FAILED', N'Batch stopped on an error; its work was rolled back or is incomplete.', 1);

UPDATE t
SET t.[Description] = s.[Description],
    t.[IsTerminal] = s.[IsTerminal],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[BatchStatus] AS t
INNER JOIN @BatchStatus AS s ON t.[BatchStatusCode] = s.[BatchStatusCode]
WHERE EXISTS (
    SELECT s.[Description], s.[IsTerminal]
    EXCEPT
    SELECT t.[Description], t.[IsTerminal]
);

INSERT INTO [reference].[BatchStatus] ([BatchStatusCode], [Description], [IsTerminal])
SELECT s.[BatchStatusCode], s.[Description], s.[IsTerminal]
FROM @BatchStatus AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[BatchStatus] AS t WHERE t.[BatchStatusCode] = s.[BatchStatusCode]);

------------------------------------------------------------------------------------------
DECLARE @BatchStepStatus TABLE (
    [BatchStepStatusCode] VARCHAR (20)   NOT NULL PRIMARY KEY,
    [Description]         NVARCHAR (200) NOT NULL,
    [IsTerminal]          BIT            NOT NULL
);

INSERT INTO @BatchStepStatus ([BatchStepStatusCode], [Description], [IsTerminal])
VALUES
    ('RUNNING', N'Step has started and has not finished.', 0),
    ('SUCCEEDED', N'Step finished successfully.', 1),
    ('FAILED', N'Step stopped on an error.', 1),
    ('SKIPPED', N'Step was not run, for example during a rerun from a later recovery point.', 1);

UPDATE t
SET t.[Description] = s.[Description],
    t.[IsTerminal] = s.[IsTerminal],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[BatchStepStatus] AS t
INNER JOIN @BatchStepStatus AS s ON t.[BatchStepStatusCode] = s.[BatchStepStatusCode]
WHERE EXISTS (
    SELECT s.[Description], s.[IsTerminal]
    EXCEPT
    SELECT t.[Description], t.[IsTerminal]
);

INSERT INTO [reference].[BatchStepStatus] ([BatchStepStatusCode], [Description], [IsTerminal])
SELECT s.[BatchStepStatusCode], s.[Description], s.[IsTerminal]
FROM @BatchStepStatus AS s
WHERE NOT EXISTS (
    SELECT 1 FROM [reference].[BatchStepStatus] AS t WHERE t.[BatchStepStatusCode] = s.[BatchStepStatusCode]
);

------------------------------------------------------------------------------------------
DECLARE @AcademicTerm TABLE (
    [TermCode]           VARCHAR (10)  NOT NULL PRIMARY KEY,
    [TermName]           NVARCHAR (50) NOT NULL,
    [TermType]           VARCHAR (10)  NOT NULL,
    [AcademicYear]       CHAR (9)      NOT NULL,
    [StartDate]          DATE          NOT NULL,
    [CensusDate]         DATE          NOT NULL,
    [EndDate]            DATE          NOT NULL,
    [IsOpenForAdmission] BIT           NOT NULL
);

INSERT INTO @AcademicTerm
    ([TermCode], [TermName], [TermType], [AcademicYear], [StartDate], [CensusDate], [EndDate], [IsOpenForAdmission])
VALUES
    ('2024FA', N'Fall 2024', 'FALL', '2024-2025', '2024-09-02', '2024-09-16', '2024-12-19', 0),
    ('2025SP', N'Spring 2025', 'SPRING', '2024-2025', '2025-01-20', '2025-02-03', '2025-05-15', 0),
    ('2025SU', N'Summer 2025', 'SUMMER', '2024-2025', '2025-06-01', '2025-06-08', '2025-08-07', 0),
    ('2025FA', N'Fall 2025', 'FALL', '2025-2026', '2025-09-02', '2025-09-16', '2025-12-19', 0),
    ('2026SP', N'Spring 2026', 'SPRING', '2025-2026', '2026-01-20', '2026-02-03', '2026-05-15', 0),
    ('2026SU', N'Summer 2026', 'SUMMER', '2025-2026', '2026-06-01', '2026-06-08', '2026-08-07', 0),
    ('2026FA', N'Fall 2026', 'FALL', '2026-2027', '2026-09-02', '2026-09-16', '2026-12-19', 0),
    ('2027SP', N'Spring 2027', 'SPRING', '2026-2027', '2027-01-20', '2027-02-03', '2027-05-15', 1),
    ('2027SU', N'Summer 2027', 'SUMMER', '2026-2027', '2027-06-01', '2027-06-08', '2027-08-07', 1),
    ('2027FA', N'Fall 2027', 'FALL', '2027-2028', '2027-09-02', '2027-09-16', '2027-12-19', 1);

UPDATE t
SET t.[TermName] = s.[TermName],
    t.[TermType] = s.[TermType],
    t.[AcademicYear] = s.[AcademicYear],
    t.[StartDate] = s.[StartDate],
    t.[CensusDate] = s.[CensusDate],
    t.[EndDate] = s.[EndDate],
    t.[IsOpenForAdmission] = s.[IsOpenForAdmission],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[AcademicTerm] AS t
INNER JOIN @AcademicTerm AS s ON t.[TermCode] = s.[TermCode]
WHERE EXISTS (
    SELECT s.[TermName], s.[TermType], s.[AcademicYear], s.[StartDate], s.[CensusDate], s.[EndDate], s.[IsOpenForAdmission]
    EXCEPT
    SELECT t.[TermName], t.[TermType], t.[AcademicYear], t.[StartDate], t.[CensusDate], t.[EndDate], t.[IsOpenForAdmission]
);

INSERT INTO [reference].[AcademicTerm]
    ([TermCode], [TermName], [TermType], [AcademicYear], [StartDate], [CensusDate], [EndDate], [IsOpenForAdmission])
SELECT s.[TermCode], s.[TermName], s.[TermType], s.[AcademicYear], s.[StartDate], s.[CensusDate], s.[EndDate], s.[IsOpenForAdmission]
FROM @AcademicTerm AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[AcademicTerm] AS t WHERE t.[TermCode] = s.[TermCode]);

------------------------------------------------------------------------------------------
DECLARE @ProgramCrosswalk TABLE (
    [SlateProgramCode] VARCHAR (20)   NOT NULL PRIMARY KEY,
    [J1ProgramCode]    VARCHAR (20)   NOT NULL,
    [ProgramName]      NVARCHAR (150) NOT NULL,
    [CredentialLevel]  VARCHAR (20)   NOT NULL,
    [CipCode]          CHAR (7)       NOT NULL,
    [IsActive]         BIT            NOT NULL,
    [EffectiveFrom]    DATE           NOT NULL,
    [EffectiveTo]      DATE           NULL
);

INSERT INTO @ProgramCrosswalk
    ([SlateProgramCode], [J1ProgramCode], [ProgramName], [CredentialLevel], [CipCode], [IsActive], [EffectiveFrom], [EffectiveTo])
VALUES
    ('ADM-ACCT', 'ACCT.AS', N'Accounting', 'ASSOCIATE', '52.0301', 1, '2020-07-01', NULL),
    ('ADM-BUS', 'BUS.AS', N'Business Administration', 'ASSOCIATE', '52.0201', 1, '2020-07-01', NULL),
    ('ADM-CIS', 'CIS.AS', N'Computer Information Systems', 'ASSOCIATE', '11.0101', 1, '2020-07-01', NULL),
    ('ADM-NURS', 'NURS.AS', N'Nursing', 'ASSOCIATE', '51.3801', 1, '2020-07-01', NULL),
    ('ADM-LIBA', 'LIBA.AS', N'Liberal Arts', 'ASSOCIATE', '24.0101', 1, '2020-07-01', NULL),
    ('ADM-CJ', 'CJ.AS', N'Criminal Justice', 'ASSOCIATE', '43.0104', 1, '2020-07-01', NULL),
    ('ADM-ECE', 'ECE.CERT', N'Early Childhood Education', 'CERTIFICATE', '19.0709', 1, '2020-07-01', NULL),
    ('ADM-WELD', 'WELD.CERT', N'Welding Technology', 'CERTIFICATE', '48.0508', 1, '2020-07-01', NULL),
    ('ADM-MEDA', 'MEDA.CERT', N'Medical Assisting', 'CERTIFICATE', '51.0801', 0, '2020-07-01', '2025-06-30');

UPDATE t
SET t.[J1ProgramCode] = s.[J1ProgramCode],
    t.[ProgramName] = s.[ProgramName],
    t.[CredentialLevel] = s.[CredentialLevel],
    t.[CipCode] = s.[CipCode],
    t.[IsActive] = s.[IsActive],
    t.[EffectiveFrom] = s.[EffectiveFrom],
    t.[EffectiveTo] = s.[EffectiveTo],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ProgramCrosswalk] AS t
INNER JOIN @ProgramCrosswalk AS s ON t.[SlateProgramCode] = s.[SlateProgramCode]
WHERE EXISTS (
    SELECT s.[J1ProgramCode], s.[ProgramName], s.[CredentialLevel], s.[CipCode], s.[IsActive], s.[EffectiveFrom], s.[EffectiveTo]
    EXCEPT
    SELECT t.[J1ProgramCode], t.[ProgramName], t.[CredentialLevel], t.[CipCode], t.[IsActive], t.[EffectiveFrom], t.[EffectiveTo]
);

INSERT INTO [reference].[ProgramCrosswalk]
    ([SlateProgramCode], [J1ProgramCode], [ProgramName], [CredentialLevel], [CipCode], [IsActive], [EffectiveFrom], [EffectiveTo])
SELECT
    s.[SlateProgramCode], s.[J1ProgramCode], s.[ProgramName], s.[CredentialLevel],
    s.[CipCode], s.[IsActive], s.[EffectiveFrom], s.[EffectiveTo]
FROM @ProgramCrosswalk AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[ProgramCrosswalk] AS t WHERE t.[SlateProgramCode] = s.[SlateProgramCode]);

------------------------------------------------------------------------------------------
DECLARE @ExceptionReason TABLE (
    [ExceptionReasonCode] VARCHAR (40)   NOT NULL PRIMARY KEY,
    [Description]         NVARCHAR (400) NOT NULL,
    [Category]            VARCHAR (20)   NOT NULL,
    [DefaultSeverity]     VARCHAR (10)   NOT NULL,
    [OwnerDepartment]     NVARCHAR (100) NOT NULL,
    [BlocksProcessing]    BIT            NOT NULL,
    [RemediationGuidance] NVARCHAR (800) NOT NULL
);

INSERT INTO @ExceptionReason
    ([ExceptionReasonCode], [Description], [Category], [DefaultSeverity], [OwnerDepartment], [BlocksProcessing], [RemediationGuidance])
VALUES
    ('MISSING_REQUIRED_FIELD',
        N'Applicant is missing a required legal name, birth date, entry term or program.',
        'VALIDATION', 'HIGH', N'Admissions', 1,
        N'Ask Admissions to complete the field in Slate-Sim; the record is retried on the next load.'),
    ('INVALID_PROGRAM',
        N'Program code is not in the program crosswalk or maps to an inactive SIS program.',
        'REFERENCE', 'HIGH', N'Admissions', 1,
        N'Correct the program choice in Slate-Sim, or have the Registrar update the crosswalk if the program is valid.'),
    ('INVALID_ENTRY_TERM',
        N'Entry term is unknown to the SIS or is closed for admission.',
        'REFERENCE', 'HIGH', N'Admissions', 1,
        N'Correct the entry term in Slate-Sim, or have the Registrar open the term if admission is intended.'),
    ('DUPLICATE_APPLICATION',
        N'More than one active application exists for the same person and entry term.',
        'VALIDATION', 'MEDIUM', N'Admissions', 1,
        N'Withdraw the superseded application in Slate-Sim.'),
    ('DUPLICATE_SIS_PERSON',
        N'Two or more SIS person records appear to represent the same individual.',
        'IDENTITY', 'HIGH', N'Registrar', 1,
        N'Registrar reviews the records and merges them in the SIS under the person-merge procedure.'),
    ('AMBIGUOUS_MATCH',
        N'More than one SIS person satisfies the same deterministic match rule.',
        'IDENTITY', 'HIGH', N'Registrar', 1,
        N'An authorized analyst selects the correct SIS person or confirms a new person; never auto-merged.'),
    ('POSSIBLE_MATCH_REVIEW',
        N'Only the review-only rule (legal name, birth date and postal code) found SIS candidates.',
        'IDENTITY', 'MEDIUM', N'Registrar', 1,
        N'An authorized analyst confirms one candidate or confirms a new person; this rule never auto-matches.'),
    ('NO_MATCH',
        N'No SIS person satisfies any automatic match rule.',
        'IDENTITY', 'MEDIUM', N'Admissions', 0,
        N'Eligible admitted applicants are created as new SIS people; otherwise review the applicant record.'),
    ('IDENTITY_CONFLICT',
        N'Immutable identifiers disagree between systems, such as one SIS ID claimed by different people.',
        'IDENTITY', 'HIGH', N'Registrar', 1,
        N'Registrar and Admissions establish the correct identifier before any retry.'),
    ('INVALID_CONTACT_FORMAT',
        N'Email address or phone number is not in a valid format.',
        'VALIDATION', 'LOW', N'Admissions', 0,
        N'Correct the contact value in Slate-Sim; processing continues without the invalid value.'),
    ('ALREADY_MATRICULATED',
        N'Applicant is already an active matriculated student in the SIS.',
        'PROCESSING', 'MEDIUM', N'Registrar', 1,
        N'Confirm whether this is a readmission or program change and route to the Registrar.'),
    ('OUTBOUND_WRITE_FAILURE',
        N'Writing the applicant to the SIS failed.',
        'PROCESSING', 'HIGH', N'Data Operations', 1,
        N'Review audit.ErrorLog for the batch, fix the cause and mark the exception RETRY_READY.'),
    ('STATUS_MISMATCH',
        N'Application status and SIS student status are mutually inconsistent.',
        'RECONCILIATION', 'MEDIUM', N'Registrar', 0,
        N'Confirm the authoritative status with Admissions and the Registrar and correct the source.'),
    ('MISSING_DIRECTORY_ACCOUNT',
        N'An active student has no enabled directory account.',
        'RECONCILIATION', 'MEDIUM', N'IT Identity Services', 0,
        N'IT Identity Services provisions the account from the SIS record.'),
    ('ORPHAN_DIRECTORY_ACCOUNT',
        N'A student directory account does not correspond to any SIS person.',
        'RECONCILIATION', 'MEDIUM', N'IT Identity Services', 0,
        N'IT Identity Services disables or relinks the account after review.'),
    ('RECONCILIATION_COUNT_MISMATCH',
        N'Batch control totals do not reconcile between source, outcomes and target.',
        'RECONCILIATION', 'HIGH', N'Data Operations', 1,
        N'Investigate the batch with the reconciliation runbook before the next scheduled load.');

UPDATE t
SET t.[Description] = s.[Description],
    t.[Category] = s.[Category],
    t.[DefaultSeverity] = s.[DefaultSeverity],
    t.[OwnerDepartment] = s.[OwnerDepartment],
    t.[BlocksProcessing] = s.[BlocksProcessing],
    t.[RemediationGuidance] = s.[RemediationGuidance],
    t.[IsActive] = 1,
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ExceptionReason] AS t
INNER JOIN @ExceptionReason AS s ON t.[ExceptionReasonCode] = s.[ExceptionReasonCode]
WHERE EXISTS (
    SELECT
        s.[Description], s.[Category], s.[DefaultSeverity], s.[OwnerDepartment],
        s.[BlocksProcessing], s.[RemediationGuidance], CAST(1 AS BIT) AS [IsActive]
    EXCEPT
    SELECT
        t.[Description], t.[Category], t.[DefaultSeverity], t.[OwnerDepartment],
        t.[BlocksProcessing], t.[RemediationGuidance], t.[IsActive]
);

INSERT INTO [reference].[ExceptionReason]
    ([ExceptionReasonCode], [Description], [Category], [DefaultSeverity],
     [OwnerDepartment], [BlocksProcessing], [RemediationGuidance], [IsActive])
SELECT
    s.[ExceptionReasonCode], s.[Description], s.[Category], s.[DefaultSeverity],
    s.[OwnerDepartment], s.[BlocksProcessing], s.[RemediationGuidance], CAST(1 AS BIT) AS [IsActive]
FROM @ExceptionReason AS s
WHERE NOT EXISTS (
    SELECT 1 FROM [reference].[ExceptionReason] AS t WHERE t.[ExceptionReasonCode] = s.[ExceptionReasonCode]
);

-- noqa: enable=RF01

COMMIT TRANSACTION;
