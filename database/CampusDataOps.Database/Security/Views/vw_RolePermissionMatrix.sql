-- Deployed permissions of every managed role (role_*), for review and for the permissions test
-- that compares them with the specified matrix (docs/architecture/security-model.md).
CREATE VIEW [security].[vw_RolePermissionMatrix]
AS
SELECT
    grantee.[name] AS [RoleName],
    dp.[state_desc] AS [PermissionState],
    dp.[permission_name] AS [PermissionName],
    dp.[class_desc] AS [ClassDesc],
    CASE dp.[class]
        WHEN 1 THEN CONCAT(OBJECT_SCHEMA_NAME(dp.[major_id]), N'.', OBJECT_NAME(dp.[major_id]))
        WHEN 3 THEN SCHEMA_NAME(dp.[major_id])
        WHEN 4 THEN USER_NAME(dp.[major_id])
        ELSE N'DATABASE'
    END AS [SecurableName]
FROM sys.database_permissions AS dp
INNER JOIN sys.database_principals AS grantee ON dp.[grantee_principal_id] = grantee.[principal_id]
WHERE grantee.[name] LIKE N'role[_]%'
  AND grantee.[type] = 'R';
