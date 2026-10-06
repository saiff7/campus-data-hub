-- One row per J1-Sim person per version received, with the student record if any.
-- Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest
-- landed version of the same key; one version per key per batch is database-enforced.
CREATE TABLE [landing].[J1PersonRaw] (
    [LandingRowId]         BIGINT            IDENTITY (1, 1) NOT NULL,
    [BatchId]              BIGINT            NOT NULL,
    [SourceSystemCode]     VARCHAR (20)      NOT NULL
        CONSTRAINT [DF_landing_J1PersonRaw_SourceSystemCode] DEFAULT ('J1_SIM'),
    [IdNumber]             INT               NOT NULL,
    [FirstName]            NVARCHAR (100)    NOT NULL,
    [MiddleName]           NVARCHAR (100)    NULL,
    [LastName]             NVARCHAR (100)    NOT NULL,
    [BirthDate]            DATE              NOT NULL,
    [Email]                NVARCHAR (320)    NULL,
    [Phone]                VARCHAR (20)      NULL,
    [AddressLine1]         NVARCHAR (200)    NULL,
    [City]                 NVARCHAR (100)    NULL,
    [StateCode]            CHAR (2)          NULL,
    [PostalCode]           VARCHAR (10)      NULL,
    [StudentProgramCode]   VARCHAR (20)      NULL,
    [StudentEntryTermCode] VARCHAR (10)      NULL,
    [StudentStatus]        VARCHAR (20)      NULL,
    [ResidencyCode]        VARCHAR (20)      NULL,
    [MatriculationDate]    DATE              NULL,
    [SourceRecordId]       AS (CONVERT(VARCHAR (64), [IdNumber])) PERSISTED NOT NULL,
    [SourceUpdatedAtUtc]   DATETIME2 (3)     NOT NULL,
    [RecordHash]           BINARY (32)       NOT NULL,
    [RequestId]            VARCHAR (100)     NOT NULL,
    [IngestedAtUtc]        DATETIME2 (3)     NOT NULL
        CONSTRAINT [DF_landing_J1PersonRaw_IngestedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_landing_J1PersonRaw] PRIMARY KEY CLUSTERED ([LandingRowId] ASC),
    CONSTRAINT [FK_landing_J1PersonRaw_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_landing_J1PersonRaw_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [CK_landing_J1PersonRaw_SourceSystemCode] CHECK ([SourceSystemCode] = 'J1_SIM')
);
GO

-- Serves the latest-version lookup (TOP 1 ... ORDER BY BatchId DESC) and enforces one
-- version per key per batch.
CREATE UNIQUE NONCLUSTERED INDEX [UX_landing_J1PersonRaw_KeyBatch]
    ON [landing].[J1PersonRaw] ([IdNumber] ASC, [BatchId] DESC)
    INCLUDE ([RecordHash]);
GO

CREATE NONCLUSTERED INDEX [IX_landing_J1PersonRaw_BatchId]
    ON [landing].[J1PersonRaw] ([BatchId] ASC);
