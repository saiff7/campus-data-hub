-- Managed role (docs/architecture/security-model.md). Members are added only through
-- security.usp_GrantRoleMembership; permissions are in Security/Permissions/RolePermissions.sql.
CREATE ROLE [role_integration_service]
    AUTHORIZATION [dbo];
