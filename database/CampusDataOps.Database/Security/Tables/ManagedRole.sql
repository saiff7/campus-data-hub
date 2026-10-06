-- The roles security.usp_GrantRoleMembership may add members to (docs/architecture/security-model.md).
-- Fixed database roles and role_security_admin are never listed: db_owner manages security admins.
CREATE TABLE [security].[ManagedRole] (
    [RoleName]     NVARCHAR (128) NOT NULL,
    [Purpose]      NVARCHAR (400) NOT NULL,
    [DataClass]    VARCHAR (30)   NOT NULL,
    [CreatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_security_ManagedRole_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_security_ManagedRole_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_security_ManagedRole] PRIMARY KEY CLUSTERED ([RoleName] ASC),
    CONSTRAINT [CK_security_ManagedRole_RoleName] CHECK ([RoleName] LIKE N'role[_]%' AND [RoleName] <> N'role_security_admin')
);
