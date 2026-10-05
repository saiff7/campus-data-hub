-- One row per Directory-Sim account per version received, with its groups as a sorted list.
-- Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest
-- landed version of the same key; one version per key per batch is database-enforced.
CREATE TABLE [landing].[DirectoryAccountRaw] (
    [LandingRowId]       BIGINT            IDENTITY (1, 1) NOT NULL,
    [BatchId]            BIGINT            NOT NULL,
    [SourceSystemCode]   VARCHAR (20)      NOT NULL
        CONSTRAINT [DF_landing_DirectoryAccountRaw_SourceSystemCode] DEFAULT ('DIRECTORY_SIM'),
    [AccountGuid]        UNIQUEIDENTIFIER  NOT NULL,
    [SamAccountName]     VARCHAR (64)      NOT NULL,
    [UserPrincipalName]  NVARCHAR (256)    NOT NULL,
    [EmployeeId]         VARCHAR (20)      NULL,
    [DisplayName]        NVARCHAR (200)    NOT NULL,
    [AccountType]        VARCHAR (10)      NOT NULL,
    [IsEnabled]          BIT               NOT NULL,
    [WhenCreatedUtc]     DATETIME2 (3)     NOT NULL,
    [GroupNames]         NVARCHAR (4000)   NULL,
    [SourceRecordId]     AS (CONVERT(VARCHAR (64), [AccountGuid])) PERSISTED NOT NULL,
    [SourceUpdatedAtUtc] DATETIME2 (3)     NOT NULL,
    [RecordHash]         BINARY (32)       NOT NULL,
    [RequestId]          VARCHAR (100)     NOT NULL,
    [IngestedAtUtc]      DATETIME2 (3)     NOT NULL
        CONSTRAINT [DF_landing_DirectoryAccountRaw_IngestedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_landing_DirectoryAccountRaw] PRIMARY KEY CLUSTERED ([LandingRowId] ASC),
    CONSTRAINT [FK_landing_DirectoryAccountRaw_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_landing_DirectoryAccountRaw_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [CK_landing_DirectoryAccountRaw_SourceSystemCode] CHECK ([SourceSystemCode] = 'DIRECTORY_SIM')
);
GO

-- Serves the latest-version lookup (TOP 1 ... ORDER BY BatchId DESC) and enforces one
-- version per key per batch.
CREATE UNIQUE NONCLUSTERED INDEX [UX_landing_DirectoryAccountRaw_KeyBatch]
    ON [landing].[DirectoryAccountRaw] ([AccountGuid] ASC, [BatchId] DESC)
    INCLUDE ([RecordHash]);
GO

CREATE NONCLUSTERED INDEX [IX_landing_DirectoryAccountRaw_BatchId]
    ON [landing].[DirectoryAccountRaw] ([BatchId] ASC);
