/*
tSQLt tests for the security model (docs/architecture/security-model.md): the deployed permissions
must equal the specified matrix, each role may read its own products and nothing raw, row-level
security limits program coordinators to their programs, and permission changes are audited.
Test users are created without logins inside each test's transaction, so nothing persists.
*/
EXEC tSQLt.NewTestClass @ClassName = N'SecurityTests';
GO

-- Tries a zero-row SELECT as the given user. @Allowed is 1 when it succeeds, 0 on a permission
-- error (229 or 230), and the error number for any other failure. The impersonation lives inside
-- one dynamic batch with its own TRY/CATCH, so REVERT always runs.
CREATE PROCEDURE [SecurityTests].[TrySelect]
    @UserName   NVARCHAR (128),
    @ObjectName NVARCHAR (256),
    @Allowed    INT = NULL OUTPUT
AS
BEGIN
    DECLARE @Sql NVARCHAR (1000) = CONCAT(
        N'EXECUTE AS USER = @User; ',
        N'BEGIN TRY SELECT TOP (0) 1 AS [Probe] FROM ', @ObjectName, N'; SET @Result = 1; END TRY ',
        N'BEGIN CATCH SET @Result = CASE WHEN ERROR_NUMBER() IN (229, 230) THEN 0 ELSE ERROR_NUMBER() END; END CATCH; ',
        N'REVERT;'
    );

    EXEC sys.sp_executesql @Sql, N'@User NVARCHAR(128), @Result INT OUTPUT', @User = @UserName, @Result = @Allowed OUTPUT;
END;
GO

-- Counts rows of an expression as the given user (same single-batch impersonation as TrySelect).
CREATE PROCEDURE [SecurityTests].[CountAs]
    @UserName NVARCHAR (128),
    @Query    NVARCHAR (800),
    @RowCount INT = NULL OUTPUT
AS
BEGIN
    DECLARE @Sql NVARCHAR (1000) = CONCAT(N'EXECUTE AS USER = @User; SELECT @Result = COUNT(*) FROM (', @Query, N') AS q; REVERT;');

    EXEC sys.sp_executesql @Sql, N'@User NVARCHAR(128), @Result INT OUTPUT', @User = @UserName, @Result = @RowCount OUTPUT;
END;
GO

CREATE PROCEDURE [SecurityTests].[AddRoleUser]
    @RoleName NVARCHAR (128)
AS
BEGIN
    DECLARE @UserName NVARCHAR (128) = CONCAT(N'test_', @RoleName);
    DECLARE @Sql NVARCHAR (400) = CONCAT(
        N'CREATE USER ', QUOTENAME(@UserName), N' WITHOUT LOGIN; ALTER ROLE ', QUOTENAME(@RoleName), N' ADD MEMBER ',
        QUOTENAME(@UserName), N';'
    );
    EXEC sys.sp_executesql @Sql;
END;
GO

CREATE PROCEDURE [SecurityTests].[test deployed permissions equal the specified matrix]
AS
BEGIN
    SELECT m.[RoleName], m.[PermissionState], m.[PermissionName], m.[ClassDesc], m.[SecurableName]
    INTO #Actual
    FROM [security].[vw_RolePermissionMatrix] AS m;

    SELECT TOP (0) a.[RoleName], a.[PermissionState], a.[PermissionName], a.[ClassDesc], a.[SecurableName]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected ([RoleName], [PermissionState], [PermissionName], [ClassDesc], [SecurableName])
    VALUES
        (N'role_auditor', 'DENY', 'DELETE', 'SCHEMA', N'core'),
        (N'role_auditor', 'DENY', 'DELETE', 'SCHEMA', N'landing'),
        (N'role_auditor', 'DENY', 'DELETE', 'SCHEMA', N'staging'),
        (N'role_auditor', 'DENY', 'INSERT', 'SCHEMA', N'core'),
        (N'role_auditor', 'DENY', 'INSERT', 'SCHEMA', N'landing'),
        (N'role_auditor', 'DENY', 'INSERT', 'SCHEMA', N'staging'),
        (N'role_auditor', 'DENY', 'SELECT', 'SCHEMA', N'core'),
        (N'role_auditor', 'DENY', 'SELECT', 'SCHEMA', N'landing'),
        (N'role_auditor', 'DENY', 'SELECT', 'SCHEMA', N'staging'),
        (N'role_auditor', 'DENY', 'UPDATE', 'SCHEMA', N'core'),
        (N'role_auditor', 'DENY', 'UPDATE', 'SCHEMA', N'landing'),
        (N'role_auditor', 'DENY', 'UPDATE', 'SCHEMA', N'staging'),
        (N'role_auditor', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.CensusSnapshot'),
        (N'role_auditor', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.ExtractControlTotal'),
        (N'role_auditor', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.ExtractRun'),
        (N'role_auditor', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'dq.vw_DataQualityScorecard'),
        (N'role_auditor', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'security.vw_RolePermissionMatrix'),
        (N'role_auditor', 'GRANT', 'SELECT', 'SCHEMA', N'audit'),
        (N'role_enrollment_reporter', 'DENY', 'DELETE', 'SCHEMA', N'core'),
        (N'role_enrollment_reporter', 'DENY', 'DELETE', 'SCHEMA', N'landing'),
        (N'role_enrollment_reporter', 'DENY', 'DELETE', 'SCHEMA', N'staging'),
        (N'role_enrollment_reporter', 'DENY', 'INSERT', 'SCHEMA', N'core'),
        (N'role_enrollment_reporter', 'DENY', 'INSERT', 'SCHEMA', N'landing'),
        (N'role_enrollment_reporter', 'DENY', 'INSERT', 'SCHEMA', N'staging'),
        (N'role_enrollment_reporter', 'DENY', 'SELECT', 'SCHEMA', N'core'),
        (N'role_enrollment_reporter', 'DENY', 'SELECT', 'SCHEMA', N'landing'),
        (N'role_enrollment_reporter', 'DENY', 'SELECT', 'SCHEMA', N'staging'),
        (N'role_enrollment_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'core'),
        (N'role_enrollment_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'landing'),
        (N'role_enrollment_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'staging'),
        (N'role_enrollment_reporter', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_GetExtractForExport'),
        (N'role_enrollment_reporter', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'reporting.usp_ReportAcademicOutcomes'),
        (N'role_enrollment_reporter', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'reporting.usp_ReportEnrollmentByTerm'),
        (N'role_enrollment_reporter', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'reporting.vw_AcademicProgress'),
        (N'role_enrollment_reporter', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'reporting.vw_EnrollmentCensus'),
        (N'role_financial_aid_reporter', 'DENY', 'DELETE', 'SCHEMA', N'core'),
        (N'role_financial_aid_reporter', 'DENY', 'DELETE', 'SCHEMA', N'landing'),
        (N'role_financial_aid_reporter', 'DENY', 'DELETE', 'SCHEMA', N'staging'),
        (N'role_financial_aid_reporter', 'DENY', 'INSERT', 'SCHEMA', N'core'),
        (N'role_financial_aid_reporter', 'DENY', 'INSERT', 'SCHEMA', N'landing'),
        (N'role_financial_aid_reporter', 'DENY', 'INSERT', 'SCHEMA', N'staging'),
        (N'role_financial_aid_reporter', 'DENY', 'SELECT', 'SCHEMA', N'core'),
        (N'role_financial_aid_reporter', 'DENY', 'SELECT', 'SCHEMA', N'landing'),
        (N'role_financial_aid_reporter', 'DENY', 'SELECT', 'SCHEMA', N'staging'),
        (N'role_financial_aid_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'core'),
        (N'role_financial_aid_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'landing'),
        (N'role_financial_aid_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'staging'),
        (N'role_financial_aid_reporter', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_GetExtractForExport'),
        (N'role_financial_aid_reporter', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'reporting.usp_ReportAidByAcademicYear'),
        (N'role_financial_aid_reporter', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'reporting.vw_FinancialAidPackaging'),
        (N'role_integration_service', 'DENY', 'DELETE', 'SCHEMA', N'core'),
        (N'role_integration_service', 'DENY', 'DELETE', 'SCHEMA', N'landing'),
        (N'role_integration_service', 'DENY', 'DELETE', 'SCHEMA', N'staging'),
        (N'role_integration_service', 'DENY', 'INSERT', 'SCHEMA', N'core'),
        (N'role_integration_service', 'DENY', 'INSERT', 'SCHEMA', N'landing'),
        (N'role_integration_service', 'DENY', 'INSERT', 'SCHEMA', N'staging'),
        (N'role_integration_service', 'DENY', 'SELECT', 'SCHEMA', N'core'),
        (N'role_integration_service', 'DENY', 'SELECT', 'SCHEMA', N'landing'),
        (N'role_integration_service', 'DENY', 'SELECT', 'SCHEMA', N'staging'),
        (N'role_integration_service', 'DENY', 'UPDATE', 'SCHEMA', N'core'),
        (N'role_integration_service', 'DENY', 'UPDATE', 'SCHEMA', N'landing'),
        (N'role_integration_service', 'DENY', 'UPDATE', 'SCHEMA', N'staging'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_CaptureCensusSnapshot'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_GenerateExtract'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_GetExtractForExport'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_RunScheduledExtracts'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'dq.usp_RecordIssueDisposition'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'integration.usp_OpenRecoveryRun'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'integration.usp_ResolveExceptionMatch'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'integration.usp_RunPipelineStep'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'integration.usp_StartPipelineRun'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'integration.usp_TransitionException'),
        (N'role_integration_service', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'reporting.usp_GetExceptionDetail'),
        (N'role_integration_service', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'reporting.vw_ExceptionWorklist'),
        (N'role_ir_analyst', 'DENY', 'DELETE', 'SCHEMA', N'core'),
        (N'role_ir_analyst', 'DENY', 'DELETE', 'SCHEMA', N'landing'),
        (N'role_ir_analyst', 'DENY', 'DELETE', 'SCHEMA', N'staging'),
        (N'role_ir_analyst', 'DENY', 'INSERT', 'SCHEMA', N'core'),
        (N'role_ir_analyst', 'DENY', 'INSERT', 'SCHEMA', N'landing'),
        (N'role_ir_analyst', 'DENY', 'INSERT', 'SCHEMA', N'staging'),
        (N'role_ir_analyst', 'DENY', 'SELECT', 'SCHEMA', N'core'),
        (N'role_ir_analyst', 'DENY', 'SELECT', 'SCHEMA', N'landing'),
        (N'role_ir_analyst', 'DENY', 'SELECT', 'SCHEMA', N'staging'),
        (N'role_ir_analyst', 'DENY', 'UPDATE', 'SCHEMA', N'core'),
        (N'role_ir_analyst', 'DENY', 'UPDATE', 'SCHEMA', N'landing'),
        (N'role_ir_analyst', 'DENY', 'UPDATE', 'SCHEMA', N'staging'),
        (N'role_ir_analyst', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_ApproveExtract'),
        (N'role_ir_analyst', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_GenerateExtract'),
        (N'role_ir_analyst', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_GetExtractForExport'),
        (N'role_ir_analyst', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_VerifyCensusSnapshot'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.CensusSnapshot'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.ExtractControlTotal'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.ExtractRun'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.MeasureDefinition'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.vw_IPEDS_12MonthEnrollment'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.vw_IPEDS_Completions'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.vw_IPEDS_FallEnrollment'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'compliance.vw_IPEDS_StudentFinancialAid'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'reporting.vw_LeadershipKPI'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'security.vw_StudentMasked'),
        (N'role_ir_analyst', 'GRANT', 'SELECT', 'SCHEMA', N'bi'),
        (N'role_program_coordinator', 'DENY', 'DELETE', 'SCHEMA', N'core'),
        (N'role_program_coordinator', 'DENY', 'DELETE', 'SCHEMA', N'landing'),
        (N'role_program_coordinator', 'DENY', 'DELETE', 'SCHEMA', N'staging'),
        (N'role_program_coordinator', 'DENY', 'INSERT', 'SCHEMA', N'core'),
        (N'role_program_coordinator', 'DENY', 'INSERT', 'SCHEMA', N'landing'),
        (N'role_program_coordinator', 'DENY', 'INSERT', 'SCHEMA', N'staging'),
        (N'role_program_coordinator', 'DENY', 'SELECT', 'SCHEMA', N'core'),
        (N'role_program_coordinator', 'DENY', 'SELECT', 'SCHEMA', N'landing'),
        (N'role_program_coordinator', 'DENY', 'SELECT', 'SCHEMA', N'staging'),
        (N'role_program_coordinator', 'DENY', 'UPDATE', 'SCHEMA', N'core'),
        (N'role_program_coordinator', 'DENY', 'UPDATE', 'SCHEMA', N'landing'),
        (N'role_program_coordinator', 'DENY', 'UPDATE', 'SCHEMA', N'staging'),
        (N'role_program_coordinator', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'reporting.vw_ProgramCensusRoster'),
        (N'role_security_admin', 'DENY', 'DELETE', 'SCHEMA', N'core'),
        (N'role_security_admin', 'DENY', 'DELETE', 'SCHEMA', N'landing'),
        (N'role_security_admin', 'DENY', 'DELETE', 'SCHEMA', N'staging'),
        (N'role_security_admin', 'DENY', 'INSERT', 'SCHEMA', N'core'),
        (N'role_security_admin', 'DENY', 'INSERT', 'SCHEMA', N'landing'),
        (N'role_security_admin', 'DENY', 'INSERT', 'SCHEMA', N'staging'),
        (N'role_security_admin', 'DENY', 'SELECT', 'SCHEMA', N'core'),
        (N'role_security_admin', 'DENY', 'SELECT', 'SCHEMA', N'landing'),
        (N'role_security_admin', 'DENY', 'SELECT', 'SCHEMA', N'staging'),
        (N'role_security_admin', 'DENY', 'UPDATE', 'SCHEMA', N'core'),
        (N'role_security_admin', 'DENY', 'UPDATE', 'SCHEMA', N'landing'),
        (N'role_security_admin', 'DENY', 'UPDATE', 'SCHEMA', N'staging'),
        (N'role_security_admin', 'GRANT', 'ALTER', 'DATABASE_PRINCIPAL', N'role_auditor'),
        (N'role_security_admin', 'GRANT', 'ALTER', 'DATABASE_PRINCIPAL', N'role_enrollment_reporter'),
        (N'role_security_admin', 'GRANT', 'ALTER', 'DATABASE_PRINCIPAL', N'role_financial_aid_reporter'),
        (N'role_security_admin', 'GRANT', 'ALTER', 'DATABASE_PRINCIPAL', N'role_integration_service'),
        (N'role_security_admin', 'GRANT', 'ALTER', 'DATABASE_PRINCIPAL', N'role_ir_analyst'),
        (N'role_security_admin', 'GRANT', 'ALTER', 'DATABASE_PRINCIPAL', N'role_program_coordinator'),
        (N'role_security_admin', 'GRANT', 'ALTER', 'DATABASE_PRINCIPAL', N'role_student_accounts_reporter'),
        (N'role_security_admin', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'security.usp_GrantRoleMembership'),
        (N'role_security_admin', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'security.usp_RevokeRoleMembership'),
        (N'role_security_admin', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'security.usp_SetProgramScope'),
        (N'role_security_admin', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'audit.AccessEvent'),
        (N'role_security_admin', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'audit.PermissionChangeEvent'),
        (N'role_security_admin', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'security.UserProgramScope'),
        (N'role_security_admin', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'security.vw_RolePermissionMatrix'),
        (N'role_student_accounts_reporter', 'DENY', 'DELETE', 'SCHEMA', N'core'),
        (N'role_student_accounts_reporter', 'DENY', 'DELETE', 'SCHEMA', N'landing'),
        (N'role_student_accounts_reporter', 'DENY', 'DELETE', 'SCHEMA', N'staging'),
        (N'role_student_accounts_reporter', 'DENY', 'INSERT', 'SCHEMA', N'core'),
        (N'role_student_accounts_reporter', 'DENY', 'INSERT', 'SCHEMA', N'landing'),
        (N'role_student_accounts_reporter', 'DENY', 'INSERT', 'SCHEMA', N'staging'),
        (N'role_student_accounts_reporter', 'DENY', 'SELECT', 'SCHEMA', N'core'),
        (N'role_student_accounts_reporter', 'DENY', 'SELECT', 'SCHEMA', N'landing'),
        (N'role_student_accounts_reporter', 'DENY', 'SELECT', 'SCHEMA', N'staging'),
        (N'role_student_accounts_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'core'),
        (N'role_student_accounts_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'landing'),
        (N'role_student_accounts_reporter', 'DENY', 'UPDATE', 'SCHEMA', N'staging'),
        (N'role_student_accounts_reporter', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'compliance.usp_GetExtractForExport'),
        (N'role_student_accounts_reporter', 'GRANT', 'EXECUTE', 'OBJECT_OR_COLUMN', N'reporting.usp_ReportAccountAging'),
        (N'role_student_accounts_reporter', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'reporting.fn_StudentAccountAging'),
        (N'role_student_accounts_reporter', 'GRANT', 'SELECT', 'OBJECT_OR_COLUMN', N'reporting.vw_StudentAccountAging');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [SecurityTests].[test each role reads its own products and nothing raw]
AS
BEGIN
    CREATE TABLE #Probe ([RoleName] NVARCHAR (128) NOT NULL, [ObjectName] NVARCHAR (256) NOT NULL, [Allowed] INT NULL);
    INSERT INTO #Probe ([RoleName], [ObjectName], [Allowed])
    VALUES
        (N'role_integration_service', N'landing.J1PersonRaw', 0),
        (N'role_integration_service', N'staging.Person', 0),
        (N'role_integration_service', N'core.vw_Student', 0),
        (N'role_integration_service', N'reporting.vw_EnrollmentCensus', 0),
        (N'role_integration_service', N'reporting.vw_FinancialAidPackaging', 0),
        (N'role_integration_service', N'reporting.vw_StudentAccountAging', 0),
        (N'role_integration_service', N'reporting.vw_LeadershipKPI', 0),
        (N'role_integration_service', N'reporting.vw_ExceptionWorklist', 1),
        (N'role_integration_service', N'security.vw_StudentMasked', 0),
        (N'role_integration_service', N'security.StudentPseudonym', 0),
        (N'role_integration_service', N'audit.AccessEvent', 0),
        (N'role_integration_service', N'compliance.ExtractRow', 0),
        (N'role_integration_service', N'integration.IntegrationException', 0),
        (N'role_enrollment_reporter', N'landing.J1PersonRaw', 0),
        (N'role_enrollment_reporter', N'staging.Person', 0),
        (N'role_enrollment_reporter', N'core.vw_Student', 0),
        (N'role_enrollment_reporter', N'reporting.vw_EnrollmentCensus', 1),
        (N'role_enrollment_reporter', N'reporting.vw_FinancialAidPackaging', 0),
        (N'role_enrollment_reporter', N'reporting.vw_StudentAccountAging', 0),
        (N'role_enrollment_reporter', N'reporting.vw_LeadershipKPI', 0),
        (N'role_enrollment_reporter', N'reporting.vw_ExceptionWorklist', 0),
        (N'role_enrollment_reporter', N'security.vw_StudentMasked', 0),
        (N'role_enrollment_reporter', N'security.StudentPseudonym', 0),
        (N'role_enrollment_reporter', N'audit.AccessEvent', 0),
        (N'role_enrollment_reporter', N'compliance.ExtractRow', 0),
        (N'role_enrollment_reporter', N'integration.IntegrationException', 0),
        (N'role_financial_aid_reporter', N'landing.J1PersonRaw', 0),
        (N'role_financial_aid_reporter', N'staging.Person', 0),
        (N'role_financial_aid_reporter', N'core.vw_Student', 0),
        (N'role_financial_aid_reporter', N'reporting.vw_EnrollmentCensus', 0),
        (N'role_financial_aid_reporter', N'reporting.vw_FinancialAidPackaging', 1),
        (N'role_financial_aid_reporter', N'reporting.vw_StudentAccountAging', 0),
        (N'role_financial_aid_reporter', N'reporting.vw_LeadershipKPI', 0),
        (N'role_financial_aid_reporter', N'reporting.vw_ExceptionWorklist', 0),
        (N'role_financial_aid_reporter', N'security.vw_StudentMasked', 0),
        (N'role_financial_aid_reporter', N'security.StudentPseudonym', 0),
        (N'role_financial_aid_reporter', N'audit.AccessEvent', 0),
        (N'role_financial_aid_reporter', N'compliance.ExtractRow', 0),
        (N'role_financial_aid_reporter', N'integration.IntegrationException', 0),
        (N'role_student_accounts_reporter', N'landing.J1PersonRaw', 0),
        (N'role_student_accounts_reporter', N'staging.Person', 0),
        (N'role_student_accounts_reporter', N'core.vw_Student', 0),
        (N'role_student_accounts_reporter', N'reporting.vw_EnrollmentCensus', 0),
        (N'role_student_accounts_reporter', N'reporting.vw_FinancialAidPackaging', 0),
        (N'role_student_accounts_reporter', N'reporting.vw_StudentAccountAging', 1),
        (N'role_student_accounts_reporter', N'reporting.vw_LeadershipKPI', 0),
        (N'role_student_accounts_reporter', N'reporting.vw_ExceptionWorklist', 0),
        (N'role_student_accounts_reporter', N'security.vw_StudentMasked', 0),
        (N'role_student_accounts_reporter', N'security.StudentPseudonym', 0),
        (N'role_student_accounts_reporter', N'audit.AccessEvent', 0),
        (N'role_student_accounts_reporter', N'compliance.ExtractRow', 0),
        (N'role_student_accounts_reporter', N'integration.IntegrationException', 0),
        (N'role_ir_analyst', N'landing.J1PersonRaw', 0),
        (N'role_ir_analyst', N'staging.Person', 0),
        (N'role_ir_analyst', N'core.vw_Student', 0),
        (N'role_ir_analyst', N'reporting.vw_EnrollmentCensus', 0),
        (N'role_ir_analyst', N'reporting.vw_FinancialAidPackaging', 0),
        (N'role_ir_analyst', N'reporting.vw_StudentAccountAging', 0),
        (N'role_ir_analyst', N'reporting.vw_LeadershipKPI', 1),
        (N'role_ir_analyst', N'reporting.vw_ExceptionWorklist', 0),
        (N'role_ir_analyst', N'security.vw_StudentMasked', 1),
        (N'role_ir_analyst', N'security.StudentPseudonym', 0),
        (N'role_ir_analyst', N'audit.AccessEvent', 0),
        (N'role_ir_analyst', N'compliance.ExtractRow', 0),
        (N'role_ir_analyst', N'integration.IntegrationException', 0),
        (N'role_program_coordinator', N'landing.J1PersonRaw', 0),
        (N'role_program_coordinator', N'staging.Person', 0),
        (N'role_program_coordinator', N'core.vw_Student', 0),
        (N'role_program_coordinator', N'reporting.vw_EnrollmentCensus', 0),
        (N'role_program_coordinator', N'reporting.vw_FinancialAidPackaging', 0),
        (N'role_program_coordinator', N'reporting.vw_StudentAccountAging', 0),
        (N'role_program_coordinator', N'reporting.vw_LeadershipKPI', 0),
        (N'role_program_coordinator', N'reporting.vw_ExceptionWorklist', 0),
        (N'role_program_coordinator', N'security.vw_StudentMasked', 0),
        (N'role_program_coordinator', N'security.StudentPseudonym', 0),
        (N'role_program_coordinator', N'audit.AccessEvent', 0),
        (N'role_program_coordinator', N'compliance.ExtractRow', 0),
        (N'role_program_coordinator', N'integration.IntegrationException', 0),
        (N'role_security_admin', N'landing.J1PersonRaw', 0),
        (N'role_security_admin', N'staging.Person', 0),
        (N'role_security_admin', N'core.vw_Student', 0),
        (N'role_security_admin', N'reporting.vw_EnrollmentCensus', 0),
        (N'role_security_admin', N'reporting.vw_FinancialAidPackaging', 0),
        (N'role_security_admin', N'reporting.vw_StudentAccountAging', 0),
        (N'role_security_admin', N'reporting.vw_LeadershipKPI', 0),
        (N'role_security_admin', N'reporting.vw_ExceptionWorklist', 0),
        (N'role_security_admin', N'security.vw_StudentMasked', 0),
        (N'role_security_admin', N'security.StudentPseudonym', 0),
        (N'role_security_admin', N'audit.AccessEvent', 1),
        (N'role_security_admin', N'compliance.ExtractRow', 0),
        (N'role_security_admin', N'integration.IntegrationException', 0),
        (N'role_auditor', N'landing.J1PersonRaw', 0),
        (N'role_auditor', N'staging.Person', 0),
        (N'role_auditor', N'core.vw_Student', 0),
        (N'role_auditor', N'reporting.vw_EnrollmentCensus', 0),
        (N'role_auditor', N'reporting.vw_FinancialAidPackaging', 0),
        (N'role_auditor', N'reporting.vw_StudentAccountAging', 0),
        (N'role_auditor', N'reporting.vw_LeadershipKPI', 0),
        (N'role_auditor', N'reporting.vw_ExceptionWorklist', 0),
        (N'role_auditor', N'security.vw_StudentMasked', 0),
        (N'role_auditor', N'security.StudentPseudonym', 0),
        (N'role_auditor', N'audit.AccessEvent', 1),
        (N'role_auditor', N'compliance.ExtractRow', 0),
        (N'role_auditor', N'integration.IntegrationException', 0);

    SELECT p.[RoleName], p.[ObjectName], p.[Allowed] INTO #Expected FROM #Probe AS p;

    DECLARE @Role NVARCHAR (128) = N'';
    WHILE 1 = 1
    BEGIN
        SELECT TOP (1) @Role = p.[RoleName] FROM #Probe AS p WHERE p.[RoleName] > @Role ORDER BY p.[RoleName];
        IF @@ROWCOUNT = 0
            BREAK;
        EXEC [SecurityTests].[AddRoleUser] @RoleName = @Role;
    END;

    DECLARE @User NVARCHAR (128);
    DECLARE @Object NVARCHAR (256);
    DECLARE @Allowed INT;
    DECLARE @Cursor CURSOR;
    SET @Cursor = CURSOR LOCAL FAST_FORWARD FOR SELECT p.[RoleName], p.[ObjectName] FROM #Probe AS p;
    OPEN @Cursor;
    FETCH NEXT FROM @Cursor INTO @Role, @Object;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @User = CONCAT(N'test_', @Role);
        EXEC [SecurityTests].[TrySelect] @UserName = @User, @ObjectName = @Object, @Allowed = @Allowed OUTPUT;
        UPDATE p SET p.[Allowed] = @Allowed FROM #Probe AS p WHERE p.[RoleName] = @Role AND p.[ObjectName] = @Object;
        FETCH NEXT FROM @Cursor INTO @Role, @Object;
    END;

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Probe';
END;
GO

CREATE PROCEDURE [SecurityTests].[test program coordinators see only the programs in their scope]
AS
BEGIN
    -- Real tables: a fake would not carry the security policy. The test transaction removes all rows.
    DECLARE @BatchId BIGINT;
    DECLARE @SnapshotId INT;
    DECLARE @Now DATETIME2 (3) = SYSUTCDATETIME();

    INSERT INTO [audit].[BatchRun] ([ProcessName], [BatchStatusCode], [RequestedAtUtc], [StartedAtUtc], [EndedAtUtc])
    VALUES ('SECURITY_TEST', 'SUCCEEDED', @Now, @Now, @Now);
    SET @BatchId = CONVERT(BIGINT, SCOPE_IDENTITY());

    INSERT INTO [compliance].[CensusSnapshot] (
        [TermCode], [CensusDate], [RuleVersion], [SourceBatchId], [CapturedAtUtc], [CapturedBy], [PopulationCount], [IncludedCount],
        [FullTimeCount], [CreditTotal], [RowChecksum]
    )
    SELECT
        t.[TermCode], t.[CensusDate], r.[RuleVersion], @BatchId AS [SourceBatchId],
        DATEADD(DAY, 1, CONVERT(DATETIME2 (3), t.[CensusDate])) AS [CapturedAtUtc],
        N'security test' AS [CapturedBy], 3 AS [PopulationCount], 3 AS [IncludedCount], 0 AS [FullTimeCount], 9.0 AS [CreditTotal],
        0x00 AS [RowChecksum]
    FROM [reference].[AcademicTerm] AS t
    CROSS JOIN [compliance].[CensusRuleVersion] AS r
    WHERE t.[TermCode] = '2027SU' AND r.[IsCurrent] = 1;
    SET @SnapshotId = CONVERT(INT, SCOPE_IDENTITY());

    INSERT INTO [compliance].[CensusSnapshotEnrollment] (
        [CensusSnapshotId], [IdNumber], [ProgramCode], [CensusCredits], [CountedSections], [AttendanceIntensity], [IsCensusIncluded]
    )
    VALUES
        (@SnapshotId, 9100001, 'NURS.AS', 3.0, 1, 'PART_TIME', 1),
        (@SnapshotId, 9100002, 'NURS.AS', 3.0, 1, 'PART_TIME', 1),
        (@SnapshotId, 9100003, 'WELD.CERT', 3.0, 1, 'PART_TIME', 1);

    EXEC [SecurityTests].[AddRoleUser] @RoleName = N'role_program_coordinator';
    CREATE USER [test_unscoped_coordinator] WITHOUT LOGIN;
    ALTER ROLE [role_program_coordinator] ADD MEMBER [test_unscoped_coordinator];
    INSERT INTO [security].[UserProgramScope] ([UserName], [ProgramCode]) VALUES (N'test_role_program_coordinator', 'NURS.AS');

    DECLARE @Scoped INT;
    DECLARE @ScopedOther INT;
    DECLARE @Unscoped INT;
    DECLARE @Owner INT = (
        SELECT COUNT(*) FROM [reporting].[vw_ProgramCensusRoster] AS r WHERE r.[TermCode] = '2027SU'
    );

    EXEC [SecurityTests].[CountAs]
        @UserName = N'test_role_program_coordinator',
        @Query = N'SELECT 1 AS [Row] FROM [reporting].[vw_ProgramCensusRoster] AS r WHERE r.[TermCode] = ''2027SU''',
        @RowCount = @Scoped OUTPUT;
    EXEC [SecurityTests].[CountAs]
        @UserName = N'test_role_program_coordinator',
        @Query = N'SELECT 1 AS [Row] FROM [reporting].[vw_ProgramCensusRoster] AS r
            WHERE r.[TermCode] = ''2027SU'' AND r.[ProgramCode] <> ''NURS.AS''',
        @RowCount = @ScopedOther OUTPUT;
    EXEC [SecurityTests].[CountAs]
        @UserName = N'test_unscoped_coordinator',
        @Query = N'SELECT 1 AS [Row] FROM [reporting].[vw_ProgramCensusRoster] AS r WHERE r.[TermCode] = ''2027SU''',
        @RowCount = @Unscoped OUTPUT;

    EXEC tSQLt.AssertEquals @Expected = 3, @Actual = @Owner;
    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @Scoped;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @ScopedOther;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Unscoped;
END;
GO

CREATE PROCEDURE [SecurityTests].[test a security admin can grant only managed roles and every change is audited]
AS
BEGIN
    EXEC [SecurityTests].[AddRoleUser] @RoleName = N'role_security_admin';
    CREATE USER [test_new_analyst] WITHOUT LOGIN;
    DECLARE @Error INT;
    DECLARE @EventsBefore INT = (SELECT COUNT(*) FROM [audit].[PermissionChangeEvent]);

    DECLARE @Sql NVARCHAR (1000) = N'EXECUTE AS USER = N''test_role_security_admin'';
        EXEC [security].[usp_GrantRoleMembership] @UserName = N''test_new_analyst'', @RoleName = N''role_ir_analyst'', @TicketReference = N''ACC-1001'';
        BEGIN TRY
            EXEC [security].[usp_GrantRoleMembership] @UserName = N''test_new_analyst'', @RoleName = N''db_owner'', @TicketReference = N''ACC-1002'';
        END TRY
        BEGIN CATCH
            SET @Result = ERROR_NUMBER();
        END CATCH;
        REVERT;';
    EXEC sys.sp_executesql @Sql, N'@Result INT OUTPUT', @Result = @Error OUTPUT;

    DECLARE @IsMember INT = (
        SELECT COUNT(*)
        FROM sys.database_role_members AS rm
        WHERE rm.[role_principal_id] = DATABASE_PRINCIPAL_ID(N'role_ir_analyst')
          AND rm.[member_principal_id] = DATABASE_PRINCIPAL_ID(N'test_new_analyst')
    );
    DECLARE @MembershipEvents INT = (
        SELECT COUNT(*) FROM [audit].[PermissionChangeEvent] AS e
        WHERE e.[EventType] = N'ADD_ROLE_MEMBER' AND e.[UserName] = N'test_role_security_admin'
    );
    DECLARE @AccessEvents INT = (
        SELECT COUNT(*) FROM [audit].[AccessEvent] AS e
        WHERE e.[EventType] = 'ROLE_GRANT' AND e.[DatabaseUser] = N'test_role_security_admin'
    );
    DECLARE @EventsAfter INT = (SELECT COUNT(*) FROM [audit].[PermissionChangeEvent]);

    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @IsMember;
    EXEC tSQLt.AssertEquals @Expected = 52301, @Actual = @Error;
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @MembershipEvents;
    EXEC tSQLt.AssertEquals @Expected = 2, @Actual = @AccessEvents;
    IF @EventsAfter <= @EventsBefore
        EXEC tSQLt.Fail @Message0 = N'No permission change was recorded.';
END;
GO

CREATE PROCEDURE [SecurityTests].[test masked outputs carry no direct identifiers]
AS
BEGIN
    -- Column-name check over every masked or Power BI object: no SIS ID, name, birth date or contact column.
    SELECT CONCAT(OBJECT_SCHEMA_NAME(c.[object_id]), N'.', OBJECT_NAME(c.[object_id]), N'.', c.[name]) AS [ColumnName]
    INTO #Leaks
    FROM sys.columns AS c
    WHERE (
        c.[object_id] IN (
            OBJECT_ID(N'security.vw_StudentMasked'), OBJECT_ID(N'reporting.vw_ProgramCensusRoster'),
            OBJECT_ID(N'reporting.vw_ExceptionWorklist'), OBJECT_ID(N'reporting.vw_LeadershipKPI')
        )
        OR OBJECT_SCHEMA_NAME(c.[object_id]) = N'bi'
    )
      AND (
          c.[name] IN (N'IdNumber', N'BirthDate', N'Email', N'EmailStd', N'EmailRaw', N'Phone', N'PhoneStd', N'PhoneRaw',
              N'AddressLine1', N'PostalCode', N'PostalCode5', N'SisIdClaim')
          OR c.[name] LIKE N'%FirstName%' OR c.[name] LIKE N'%LastName%'
      );

    EXEC tSQLt.AssertEmptyTable @TableName = N'#Leaks';
END;
GO
