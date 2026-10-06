-- Every database security change (GRANT, DENY, REVOKE, role membership, user and role DDL),
-- written by the database DDL trigger trg_audit_PermissionChange (docs/architecture/security-model.md).
CREATE TABLE [audit].[PermissionChangeEvent] (
    [PermissionChangeEventId] BIGINT          IDENTITY (1, 1) NOT NULL,
    [EventType]               NVARCHAR (64)   NOT NULL,
    [LoginName]               NVARCHAR (128)  NULL,
    [UserName]                NVARCHAR (128)  NULL,
    [ObjectName]              NVARCHAR (256)  NULL,
    [Permissions]             NVARCHAR (400)  NULL,
    [Grantees]                NVARCHAR (400)  NULL,
    [CommandText]             NVARCHAR (2000) NULL,
    [OccurredAtUtc]           DATETIME2 (3)   CONSTRAINT [DF_audit_PermissionChangeEvent_OccurredAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_audit_PermissionChangeEvent] PRIMARY KEY CLUSTERED ([PermissionChangeEventId] ASC)
);
