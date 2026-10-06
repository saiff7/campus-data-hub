/*
Compliance seed (ADR-003, docs/specifications/report-catalog.md, extract-controls.md and
ipeds-measure-mapping.md). Same contract as reference_seed.sql: idempotent, inserts missing
rows, updates rows whose governed values differ, never deletes. A census rule version that has
snapshots must never change: add a new version and make it current instead.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- noqa: disable=RF01

BEGIN TRANSACTION;

DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

------------------------------------------------------------------------------------------
DECLARE @CensusRuleVersion TABLE (
    [RuleVersion]        VARCHAR (20)   NOT NULL,
    [Description]        NVARCHAR (400) NOT NULL,
    [FullTimeMinCredits] DECIMAL (4, 1) NOT NULL,
    [EffectiveFrom]      DATE           NOT NULL,
    [IsCurrent]          BIT            NOT NULL,
    PRIMARY KEY ([RuleVersion])
);

INSERT INTO @CensusRuleVersion ([RuleVersion], [Description], [FullTimeMinCredits], [EffectiveFrom], [IsCurrent])
VALUES
    ('CENSUS-1', N'Sections counted at the end of the census date; full-time at 12 or more credits.', 12.0, '2024-07-01', 1);

IF EXISTS (
    SELECT 1
    FROM [compliance].[CensusRuleVersion] AS t
    INNER JOIN @CensusRuleVersion AS s ON t.[RuleVersion] = s.[RuleVersion]
    WHERE t.[FullTimeMinCredits] <> s.[FullTimeMinCredits]
      AND EXISTS (SELECT 1 FROM [compliance].[CensusSnapshot] AS cs WHERE cs.[RuleVersion] = t.[RuleVersion])
)
    THROW 52020, N'A census rule version with snapshots cannot change; add a new version instead (ADR-003).', 1;

UPDATE t
SET t.[Description] = s.[Description],
    t.[FullTimeMinCredits] = s.[FullTimeMinCredits],
    t.[EffectiveFrom] = s.[EffectiveFrom],
    t.[IsCurrent] = s.[IsCurrent],
    t.[UpdatedAtUtc] = @NowUtc
FROM [compliance].[CensusRuleVersion] AS t
INNER JOIN @CensusRuleVersion AS s ON t.[RuleVersion] = s.[RuleVersion]
WHERE EXISTS (
    SELECT s.[Description], s.[FullTimeMinCredits], s.[EffectiveFrom], s.[IsCurrent]
    EXCEPT
    SELECT t.[Description], t.[FullTimeMinCredits], t.[EffectiveFrom], t.[IsCurrent]
);

INSERT INTO [compliance].[CensusRuleVersion] ([RuleVersion], [Description], [FullTimeMinCredits], [EffectiveFrom],
    [IsCurrent])
SELECT s.[RuleVersion], s.[Description], s.[FullTimeMinCredits], s.[EffectiveFrom], s.[IsCurrent]
FROM @CensusRuleVersion AS s
WHERE NOT EXISTS (SELECT 1 FROM [compliance].[CensusRuleVersion] AS t WHERE t.[RuleVersion] = s.[RuleVersion]);

------------------------------------------------------------------------------------------
DECLARE @MeasureDefinition TABLE (
    [MeasureCode]         VARCHAR (40)   NOT NULL,
    [MeasureName]         NVARCHAR (100) NOT NULL,
    [Definition]          NVARCHAR (600) NOT NULL,
    [Unit]                VARCHAR (10)   NOT NULL,
    [OwnerDepartmentCode] VARCHAR (30)   NOT NULL,
    [Grain]               NVARCHAR (100) NOT NULL,
    [InclusionRule]       NVARCHAR (400) NOT NULL,
    [AsOfBehavior]        VARCHAR (15)   NOT NULL,
    [SourceLineage]       NVARCHAR (400) NOT NULL,
    [IsAssumption]        BIT            NOT NULL,
    [SortOrder]           TINYINT        NOT NULL,
    PRIMARY KEY ([MeasureCode])
);

INSERT INTO @MeasureDefinition ([MeasureCode], [MeasureName], [Definition], [Unit], [OwnerDepartmentCode], [Grain],
    [InclusionRule], [AsOfBehavior], [SourceLineage], [IsAssumption], [SortOrder])
VALUES
    ('APPLICATIONS', N'Applications',
        N'Applications for the entry term with status SUBMITTED or later (not STARTED).',
        'COUNT', 'ADMISSIONS', N'Entry term',
        N'Every Slate-Sim application whose raw entry term is a governed term.', 'CURRENT',
        N'SlateSim.Application > landing.SlateApplicationRaw > staging.Applicant > core.vw_Application', 0, 1),
    ('ADMITS', N'Admits',
        N'Applications whose status is ADMITTED or DEPOSITED.',
        'COUNT', 'ADMISSIONS', N'Entry term',
        N'As APPLICATIONS, status ADMITTED or DEPOSITED.', 'CURRENT',
        N'core.vw_Application', 0, 2),
    ('DEPOSITS', N'Deposits',
        N'Applications whose status is DEPOSITED.',
        'COUNT', 'ADMISSIONS', N'Entry term',
        N'As APPLICATIONS, status DEPOSITED.', 'CURRENT',
        N'core.vw_Application', 0, 3),
    ('YIELD_RATE', N'Yield rate',
        N'DEPOSITS divided by ADMITS; NULL when there are no admits.',
        'RATIO', 'ADMISSIONS', N'Entry term',
        N'Derived from ADMITS and DEPOSITS.', 'CURRENT',
        N'core.vw_Application', 0, 4),
    ('CENSUS_HEADCOUNT', N'Census headcount',
        N'Students included at census under the current census rule version.',
        'COUNT', 'REGISTRAR', N'Term',
        N'Snapshot rows with IsCensusIncluded = 1.', 'CENSUS_SNAPSHOT',
        N'compliance.CensusSnapshot (IncludedCount)', 0, 5),
    ('CENSUS_FTE', N'Census FTE',
        N'Census credits divided by 15 (term FTE divisor).',
        'FTE', 'INSTITUTIONAL_RESEARCH', N'Term',
        N'Credits of included students at census.', 'CENSUS_SNAPSHOT',
        N'compliance.CensusSnapshot (CreditTotal)', 1, 6),
    ('FULL_TIME_SHARE', N'Full-time share',
        N'Full-time included students divided by included students.',
        'RATIO', 'REGISTRAR', N'Term',
        N'Included snapshot rows; full-time per the rule version threshold.', 'CENSUS_SNAPSHOT',
        N'compliance.CensusSnapshot (FullTimeCount, IncludedCount)', 0, 7),
    ('AID_RECIPIENTS', N'Aid recipients',
        N'Distinct students with an ACCEPTED award in the term.',
        'COUNT', 'FINANCIAL_AID', N'Term',
        N'Awards with status ACCEPTED.', 'CURRENT',
        N'J1Sim.FinancialAidAward > staging.FinancialAidAward > core.vw_AidAward', 0, 8),
    ('OUTSTANDING_BALANCE', N'Outstanding balance',
        N'Sum of positive net account balances on the earlier of the term end date and today.',
        'USD', 'STUDENT_ACCOUNTS', N'Term',
        N'Every student with a positive net balance on that date.', 'CURRENT',
        N'staging.AccountTransaction > core.vw_AccountTransaction > reporting.fn_StudentAccountAging', 0, 9),
    ('COURSE_SUCCESS_RATE', N'Course success rate',
        N'Sections graded C or better (grade points >= 2.00) divided by sections with any final grade, including W, F and I.',
        'RATIO', 'ACADEMIC_AFFAIRS', N'Term',
        N'Non-dropped sections with a posted grade; NULL until grades exist.', 'CURRENT',
        N'J1Sim.Enrollment, FinalGrade > staging.Enrollment > core.vw_Enrollment', 1, 10),
    ('COMPLETIONS', N'Completions',
        N'Credentials awarded with the term as their award term.',
        'COUNT', 'REGISTRAR', N'Term',
        N'Every credential award.', 'CURRENT',
        N'J1Sim.CredentialAwarded > staging.CredentialAwarded > core.vw_Credential', 0, 11);

UPDATE t
SET t.[MeasureName] = s.[MeasureName],
    t.[Definition] = s.[Definition],
    t.[Unit] = s.[Unit],
    t.[OwnerDepartmentCode] = s.[OwnerDepartmentCode],
    t.[Grain] = s.[Grain],
    t.[InclusionRule] = s.[InclusionRule],
    t.[AsOfBehavior] = s.[AsOfBehavior],
    t.[SourceLineage] = s.[SourceLineage],
    t.[IsAssumption] = s.[IsAssumption],
    t.[SortOrder] = s.[SortOrder],
    t.[UpdatedAtUtc] = @NowUtc
FROM [compliance].[MeasureDefinition] AS t
INNER JOIN @MeasureDefinition AS s ON t.[MeasureCode] = s.[MeasureCode]
WHERE EXISTS (
    SELECT s.[MeasureName], s.[Definition], s.[Unit], s.[OwnerDepartmentCode], s.[Grain], s.[InclusionRule],
        s.[AsOfBehavior], s.[SourceLineage], s.[IsAssumption], s.[SortOrder]
    EXCEPT
    SELECT t.[MeasureName], t.[Definition], t.[Unit], t.[OwnerDepartmentCode], t.[Grain], t.[InclusionRule],
        t.[AsOfBehavior], t.[SourceLineage], t.[IsAssumption], t.[SortOrder]
);

INSERT INTO [compliance].[MeasureDefinition] ([MeasureCode], [MeasureName], [Definition], [Unit], [OwnerDepartmentCode],
    [Grain], [InclusionRule], [AsOfBehavior], [SourceLineage], [IsAssumption], [SortOrder])
SELECT s.[MeasureCode], s.[MeasureName], s.[Definition], s.[Unit], s.[OwnerDepartmentCode], s.[Grain],
    s.[InclusionRule], s.[AsOfBehavior], s.[SourceLineage], s.[IsAssumption], s.[SortOrder]
FROM @MeasureDefinition AS s
WHERE NOT EXISTS (SELECT 1 FROM [compliance].[MeasureDefinition] AS t WHERE t.[MeasureCode] = s.[MeasureCode]);


-- noqa: enable=RF01

COMMIT TRANSACTION;
