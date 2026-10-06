/*
DEVELOPMENT ONLY. Deletes every operational row in CampusDataOps (landing, staging,
integration, data-quality and audit history) while keeping the schema, the governed reference
data and any installed tSQLt tests. Landing is append-only by design (ADR-002); this script
exists only so a developer or a test suite can start again from an empty platform after
reseeding the simulators. It is not part of the DACPAC and must never run in a shared
environment.

    make reset-ops CONFIRM=1
    sqlcmd ... -v ConfirmReset=YES -i reset_operational_data.sql
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- sqlcmd substitutes $(ConfirmReset) before execution, so this is not a constant comparison.
IF N'$(ConfirmReset)' <> N'YES' -- noqa: ST10
    THROW 50900, N'Refusing to delete operational data without ConfirmReset=YES.', 1;

BEGIN TRANSACTION;

DELETE FROM [integration].[ReconciliationDetail];
DELETE FROM [integration].[ReconciliationResult];
DELETE FROM [integration].[ReconciliationEntityCount];
DELETE FROM [integration].[ExceptionAction];
DELETE FROM [integration].[IntegrationException];
DELETE FROM [integration].[SourceCrosswalk];
DELETE FROM [integration].[OutboundStudentQueue];
DELETE FROM [integration].[MatchCandidate];
DELETE FROM [integration].[MatchDecision];
DELETE FROM [integration].[MatchEvaluation];
DELETE FROM [dq].[RuleResult];
DELETE FROM [dq].[RuleExecution];
DELETE FROM [dq].[ValidationRun];
DELETE FROM [staging].[Applicant];
DELETE FROM [staging].[Person];
DELETE FROM [staging].[DirectoryAccount];
DELETE FROM [staging].[Enrollment];
DELETE FROM [staging].[FinancialAidAward];
DELETE FROM [staging].[AccountTransaction];
DELETE FROM [staging].[CredentialAwarded];
DELETE FROM [landing].[SlateApplicantRaw];
DELETE FROM [landing].[SlateApplicationRaw];
DELETE FROM [landing].[J1PersonRaw];
DELETE FROM [landing].[J1EnrollmentRaw];
DELETE FROM [landing].[J1FinancialAidRaw];
DELETE FROM [landing].[J1AccountTransactionRaw];
DELETE FROM [landing].[J1AccountControlTotal];
DELETE FROM [landing].[DirectoryAccountRaw];
DELETE FROM [landing].[J1CredentialRaw];
-- Completed extract runs and census snapshots are immutable; only this development reset may
-- remove them.
ALTER TABLE [compliance].[ExtractControlTotal] DISABLE TRIGGER [trg_ExtractControlTotal_Immutable];
ALTER TABLE [compliance].[ExtractRow] DISABLE TRIGGER [trg_ExtractRow_Immutable];
ALTER TABLE [compliance].[ExtractRun] DISABLE TRIGGER [trg_ExtractRun_Immutable];
DELETE FROM [compliance].[ExtractControlTotal];
DELETE FROM [compliance].[ExtractRow];
DELETE FROM [compliance].[ExtractRun];
ALTER TABLE [compliance].[ExtractRun] ENABLE TRIGGER [trg_ExtractRun_Immutable];
ALTER TABLE [compliance].[ExtractRow] ENABLE TRIGGER [trg_ExtractRow_Immutable];
ALTER TABLE [compliance].[ExtractControlTotal] ENABLE TRIGGER [trg_ExtractControlTotal_Immutable];
ALTER TABLE [compliance].[CensusSnapshotEnrollment] DISABLE TRIGGER [trg_CensusSnapshotEnrollment_Immutable];
ALTER TABLE [compliance].[CensusSnapshot] DISABLE TRIGGER [trg_CensusSnapshot_Immutable];
DELETE FROM [compliance].[CensusSnapshotEnrollment];
DELETE FROM [compliance].[CensusSnapshot];
ALTER TABLE [compliance].[CensusSnapshot] ENABLE TRIGGER [trg_CensusSnapshot_Immutable];
ALTER TABLE [compliance].[CensusSnapshotEnrollment] ENABLE TRIGGER [trg_CensusSnapshotEnrollment_Immutable];
DELETE FROM [audit].[AccessEvent];
DELETE FROM [audit].[ErrorLog];
DELETE FROM [audit].[BatchStep];
UPDATE br SET br.[ParentBatchId] = NULL, br.[RecoveryOfBatchId] = NULL FROM [audit].[BatchRun] AS br;
DELETE FROM [audit].[BatchRun];

COMMIT TRANSACTION;

PRINT N'Operational data deleted.';
