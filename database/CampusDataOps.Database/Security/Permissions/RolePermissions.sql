-- Role permissions: the specified matrix in docs/architecture/security-model.md. Keep the two in
-- step; SecurityTests compares the deployed permissions with the matrix and fails on any difference.
-- Department roles get SELECT or EXECUTE on curated objects only. Every managed role is denied the
-- raw layers; reports still work through dbo ownership chaining.

-- role_integration_service
GRANT EXECUTE ON OBJECT::[integration].[usp_StartPipelineRun] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[integration].[usp_RunPipelineStep] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[integration].[usp_OpenRecoveryRun] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[integration].[usp_TransitionException] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[integration].[usp_ResolveExceptionMatch] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_CaptureCensusSnapshot] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_RunScheduledExtracts] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_GenerateExtract] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_GetExtractForExport] TO [role_integration_service];
GO
GRANT EXECUTE ON OBJECT::[reporting].[usp_GetExceptionDetail] TO [role_integration_service];
GO
GRANT SELECT ON OBJECT::[reporting].[vw_ExceptionWorklist] TO [role_integration_service];
GO

-- role_enrollment_reporter
GRANT SELECT ON OBJECT::[reporting].[vw_EnrollmentCensus] TO [role_enrollment_reporter];
GO
GRANT SELECT ON OBJECT::[reporting].[vw_AcademicProgress] TO [role_enrollment_reporter];
GO
GRANT EXECUTE ON OBJECT::[reporting].[usp_ReportEnrollmentByTerm] TO [role_enrollment_reporter];
GO
GRANT EXECUTE ON OBJECT::[reporting].[usp_ReportAcademicOutcomes] TO [role_enrollment_reporter];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_GetExtractForExport] TO [role_enrollment_reporter];
GO

-- role_financial_aid_reporter
GRANT SELECT ON OBJECT::[reporting].[vw_FinancialAidPackaging] TO [role_financial_aid_reporter];
GO
GRANT EXECUTE ON OBJECT::[reporting].[usp_ReportAidByAcademicYear] TO [role_financial_aid_reporter];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_GetExtractForExport] TO [role_financial_aid_reporter];
GO

-- role_student_accounts_reporter
GRANT SELECT ON OBJECT::[reporting].[vw_StudentAccountAging] TO [role_student_accounts_reporter];
GO
GRANT SELECT ON OBJECT::[reporting].[fn_StudentAccountAging] TO [role_student_accounts_reporter];
GO
GRANT EXECUTE ON OBJECT::[reporting].[usp_ReportAccountAging] TO [role_student_accounts_reporter];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_GetExtractForExport] TO [role_student_accounts_reporter];
GO

-- role_ir_analyst
GRANT SELECT ON OBJECT::[reporting].[vw_LeadershipKPI] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[compliance].[vw_IPEDS_FallEnrollment] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[compliance].[vw_IPEDS_12MonthEnrollment] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[compliance].[vw_IPEDS_Completions] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[compliance].[vw_IPEDS_StudentFinancialAid] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[compliance].[MeasureDefinition] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[compliance].[ExtractRun] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[compliance].[ExtractControlTotal] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[compliance].[CensusSnapshot] TO [role_ir_analyst];
GO
GRANT SELECT ON OBJECT::[security].[vw_StudentMasked] TO [role_ir_analyst];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_GenerateExtract] TO [role_ir_analyst];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_ApproveExtract] TO [role_ir_analyst];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_GetExtractForExport] TO [role_ir_analyst];
GO
GRANT EXECUTE ON OBJECT::[compliance].[usp_VerifyCensusSnapshot] TO [role_ir_analyst];
GO

-- role_program_coordinator
GRANT SELECT ON OBJECT::[reporting].[vw_ProgramCensusRoster] TO [role_program_coordinator];
GO

-- role_security_admin
GRANT EXECUTE ON OBJECT::[security].[usp_GrantRoleMembership] TO [role_security_admin];
GO
GRANT EXECUTE ON OBJECT::[security].[usp_RevokeRoleMembership] TO [role_security_admin];
GO
GRANT EXECUTE ON OBJECT::[security].[usp_SetProgramScope] TO [role_security_admin];
GO
GRANT SELECT ON OBJECT::[security].[UserProgramScope] TO [role_security_admin];
GO
GRANT SELECT ON OBJECT::[security].[vw_RolePermissionMatrix] TO [role_security_admin];
GO
GRANT SELECT ON OBJECT::[audit].[AccessEvent] TO [role_security_admin];
GO
GRANT SELECT ON OBJECT::[audit].[PermissionChangeEvent] TO [role_security_admin];
GO

-- role_auditor
GRANT SELECT ON OBJECT::[security].[vw_RolePermissionMatrix] TO [role_auditor];
GO
GRANT SELECT ON OBJECT::[compliance].[ExtractRun] TO [role_auditor];
GO
GRANT SELECT ON OBJECT::[compliance].[ExtractControlTotal] TO [role_auditor];
GO
GRANT SELECT ON OBJECT::[compliance].[CensusSnapshot] TO [role_auditor];
GO
GRANT SELECT ON OBJECT::[dq].[vw_DataQualityScorecard] TO [role_auditor];
GO

-- Schema-wide read for the Power BI star schema (IR) and for audit history (auditors).
GRANT SELECT ON SCHEMA::[bi] TO [role_ir_analyst];
GO
GRANT SELECT ON SCHEMA::[audit] TO [role_auditor];
GO

-- Security administrators may change membership of the department roles only (ALTER on a role
-- allows adding and removing members); db_owner manages role_security_admin itself.
GRANT ALTER ON ROLE::[role_integration_service] TO [role_security_admin];
GO
GRANT ALTER ON ROLE::[role_enrollment_reporter] TO [role_security_admin];
GO
GRANT ALTER ON ROLE::[role_financial_aid_reporter] TO [role_security_admin];
GO
GRANT ALTER ON ROLE::[role_student_accounts_reporter] TO [role_security_admin];
GO
GRANT ALTER ON ROLE::[role_ir_analyst] TO [role_security_admin];
GO
GRANT ALTER ON ROLE::[role_program_coordinator] TO [role_security_admin];
GO
GRANT ALTER ON ROLE::[role_auditor] TO [role_security_admin];
GO

-- Raw layers are denied to every managed role; DENY overrides any accidental grant.
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[landing] TO [role_integration_service];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[landing] TO [role_enrollment_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[landing] TO [role_financial_aid_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[landing] TO [role_student_accounts_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[landing] TO [role_ir_analyst];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[landing] TO [role_program_coordinator];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[landing] TO [role_security_admin];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[landing] TO [role_auditor];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[staging] TO [role_integration_service];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[staging] TO [role_enrollment_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[staging] TO [role_financial_aid_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[staging] TO [role_student_accounts_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[staging] TO [role_ir_analyst];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[staging] TO [role_program_coordinator];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[staging] TO [role_security_admin];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[staging] TO [role_auditor];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[core] TO [role_integration_service];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[core] TO [role_enrollment_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[core] TO [role_financial_aid_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[core] TO [role_student_accounts_reporter];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[core] TO [role_ir_analyst];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[core] TO [role_program_coordinator];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[core] TO [role_security_admin];
GO
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[core] TO [role_auditor];
GO
