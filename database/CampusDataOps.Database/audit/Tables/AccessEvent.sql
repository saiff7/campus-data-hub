-- Privileged data access: extract generation, export and approval, exception drill-through and
-- security administration (docs/architecture/security-model.md). Refused attempts are logged
-- too (IsAllowed = 0). Detail holds codes and reasons, never protected values.
CREATE TABLE [audit].[AccessEvent] (
    [AccessEventId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [EventType]     VARCHAR (30)   NOT NULL,
    [ObjectName]    NVARCHAR (256) NOT NULL,
    [DatabaseUser]  NVARCHAR (128) CONSTRAINT [DF_audit_AccessEvent_DatabaseUser] DEFAULT (USER_NAME()) NOT NULL,
    [OriginalLogin] NVARCHAR (128) CONSTRAINT [DF_audit_AccessEvent_OriginalLogin] DEFAULT (ORIGINAL_LOGIN()) NOT NULL,
    [IsPrivileged]  BIT            NOT NULL,
    [IsAllowed]     BIT            NOT NULL,
    [ExtractRunId]  BIGINT         NULL,
    [SubjectKey]    VARCHAR (100)  NULL,
    [Detail]        NVARCHAR (400) NULL,
    [OccurredAtUtc] DATETIME2 (3)  CONSTRAINT [DF_audit_AccessEvent_OccurredAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_audit_AccessEvent] PRIMARY KEY CLUSTERED ([AccessEventId] ASC),
    CONSTRAINT [CK_audit_AccessEvent_EventType]
        CHECK (([EventType] = 'EXTRACT_GENERATE' OR [EventType] = 'EXTRACT_EXPORT' OR [EventType] = 'EXTRACT_APPROVE'
            OR [EventType] = 'EXTRACT_REJECT' OR [EventType] = 'EXCEPTION_DRILLTHROUGH' OR [EventType] = 'ROLE_GRANT'
            OR [EventType] = 'ROLE_REVOKE' OR [EventType] = 'PROGRAM_SCOPE_CHANGE'))
);
GO

CREATE NONCLUSTERED INDEX [IX_audit_AccessEvent_OccurredAtUtc]
    ON [audit].[AccessEvent] ([OccurredAtUtc] ASC)
    INCLUDE ([EventType], [DatabaseUser], [IsAllowed]);
