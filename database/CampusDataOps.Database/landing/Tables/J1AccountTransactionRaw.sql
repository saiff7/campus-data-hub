-- One row per J1-Sim student account transaction per version received.
-- Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest
-- landed version of the same key; one version per key per batch is database-enforced.
CREATE TABLE [landing].[J1AccountTransactionRaw] (
    [LandingRowId]       BIGINT            IDENTITY (1, 1) NOT NULL,
    [BatchId]            BIGINT            NOT NULL,
    [SourceSystemCode]   VARCHAR (20)      NOT NULL
        CONSTRAINT [DF_landing_J1AccountTransactionRaw_SourceSystemCode] DEFAULT ('J1_SIM'),
    [TransactionId]      BIGINT            NOT NULL,
    [IdNumber]           INT               NOT NULL,
    [TermCode]           VARCHAR (10)      NOT NULL,
    [TransactionType]    VARCHAR (12)      NOT NULL,
    [DetailCode]         VARCHAR (10)      NOT NULL,
    [Amount]             DECIMAL (12, 2)   NOT NULL,
    [PostedDate]         DATE              NOT NULL,
    [DueDate]            DATE              NULL,
    [SourceRecordId]     AS (CONVERT(VARCHAR (64), [TransactionId])) PERSISTED NOT NULL,
    [SourceUpdatedAtUtc] DATETIME2 (3)     NOT NULL,
    [RecordHash]         BINARY (32)       NOT NULL,
    [RequestId]          VARCHAR (100)     NOT NULL,
    [IngestedAtUtc]      DATETIME2 (3)     NOT NULL
        CONSTRAINT [DF_landing_J1AccountTransactionRaw_IngestedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_landing_J1AccountTransactionRaw] PRIMARY KEY CLUSTERED ([LandingRowId] ASC),
    CONSTRAINT [FK_landing_J1AccountTransactionRaw_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_landing_J1AccountTransactionRaw_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [CK_landing_J1AccountTransactionRaw_SourceSystemCode] CHECK ([SourceSystemCode] = 'J1_SIM')
);
GO

-- Serves the latest-version lookup (TOP 1 ... ORDER BY BatchId DESC) and enforces one
-- version per key per batch.
CREATE UNIQUE NONCLUSTERED INDEX [UX_landing_J1AccountTransactionRaw_KeyBatch]
    ON [landing].[J1AccountTransactionRaw] ([TransactionId] ASC, [BatchId] DESC)
    INCLUDE ([RecordHash]);
GO

CREATE NONCLUSTERED INDEX [IX_landing_J1AccountTransactionRaw_BatchId]
    ON [landing].[J1AccountTransactionRaw] ([BatchId] ASC);
