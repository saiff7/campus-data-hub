-- One row per Slate-Sim application per version received, with ranked program choices
-- and the admitted-applicant export time.
-- Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest
-- landed version of the same key; one version per key per batch is database-enforced.
CREATE TABLE [landing].[SlateApplicationRaw] (
    [LandingRowId]       BIGINT            IDENTITY (1, 1) NOT NULL,
    [BatchId]            BIGINT            NOT NULL,
    [SourceSystemCode]   VARCHAR (20)      NOT NULL
        CONSTRAINT [DF_landing_SlateApplicationRaw_SourceSystemCode] DEFAULT ('SLATE_SIM'),
    [ApplicationId]      UNIQUEIDENTIFIER  NOT NULL,
    [PersonId]           UNIQUEIDENTIFIER  NOT NULL,
    [EntryTermCode]      VARCHAR (10)      NULL,
    [StudentType]        VARCHAR (20)      NOT NULL,
    [ApplicationStatus]  VARCHAR (20)      NOT NULL,
    [SubmittedAtUtc]     DATETIME2 (3)     NULL,
    [DecisionAtUtc]      DATETIME2 (3)     NULL,
    [ProgramChoice1]     VARCHAR (20)      NULL,
    [ProgramChoice2]     VARCHAR (20)      NULL,
    [ProgramChoice3]     VARCHAR (20)      NULL,
    [ExportQueuedAtUtc]  DATETIME2 (3)     NULL,
    [SourceRecordId]     AS (CONVERT(VARCHAR (64), [ApplicationId])) PERSISTED NOT NULL,
    [SourceUpdatedAtUtc] DATETIME2 (3)     NOT NULL,
    [RecordHash]         BINARY (32)       NOT NULL,
    [RequestId]          VARCHAR (100)     NOT NULL,
    [IngestedAtUtc]      DATETIME2 (3)     NOT NULL
        CONSTRAINT [DF_landing_SlateApplicationRaw_IngestedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_landing_SlateApplicationRaw] PRIMARY KEY CLUSTERED ([LandingRowId] ASC),
    CONSTRAINT [FK_landing_SlateApplicationRaw_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_landing_SlateApplicationRaw_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [CK_landing_SlateApplicationRaw_SourceSystemCode] CHECK ([SourceSystemCode] = 'SLATE_SIM')
);
GO

-- Serves the latest-version lookup (TOP 1 ... ORDER BY BatchId DESC) and enforces one
-- version per key per batch.
CREATE UNIQUE NONCLUSTERED INDEX [UX_landing_SlateApplicationRaw_KeyBatch]
    ON [landing].[SlateApplicationRaw] ([ApplicationId] ASC, [BatchId] DESC)
    INCLUDE ([RecordHash]);
GO

CREATE NONCLUSTERED INDEX [IX_landing_SlateApplicationRaw_BatchId]
    ON [landing].[SlateApplicationRaw] ([BatchId] ASC);
