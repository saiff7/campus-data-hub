-- Source-side count and sum of account transactions per student and term, captured when
-- any transaction in the group changed. dq.usp_CheckAccountControlTotals reconciles staged
-- detail to the latest captured total.
-- Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest
-- landed version of the same key; one version per key per batch is database-enforced.
CREATE TABLE [landing].[J1AccountControlTotal] (
    [LandingRowId]       BIGINT            IDENTITY (1, 1) NOT NULL,
    [BatchId]            BIGINT            NOT NULL,
    [SourceSystemCode]   VARCHAR (20)      NOT NULL
        CONSTRAINT [DF_landing_J1AccountControlTotal_SourceSystemCode] DEFAULT ('J1_SIM'),
    [IdNumber]           INT               NOT NULL,
    [TermCode]           VARCHAR (10)      NOT NULL,
    [TransactionCount]   INT               NOT NULL,
    [AmountTotal]        DECIMAL (14, 2)   NOT NULL,
    [SourceRecordId]     AS (CONVERT(VARCHAR (12), [IdNumber]) + '|' + [TermCode]) PERSISTED NOT NULL,
    [SourceUpdatedAtUtc] DATETIME2 (3)     NOT NULL,
    [RecordHash]         BINARY (32)       NOT NULL,
    [RequestId]          VARCHAR (100)     NOT NULL,
    [IngestedAtUtc]      DATETIME2 (3)     NOT NULL
        CONSTRAINT [DF_landing_J1AccountControlTotal_IngestedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_landing_J1AccountControlTotal] PRIMARY KEY CLUSTERED ([LandingRowId] ASC),
    CONSTRAINT [FK_landing_J1AccountControlTotal_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_landing_J1AccountControlTotal_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [CK_landing_J1AccountControlTotal_SourceSystemCode] CHECK ([SourceSystemCode] = 'J1_SIM')
);
GO

-- Serves the latest-version lookup (TOP 1 ... ORDER BY BatchId DESC) and enforces one
-- version per key per batch.
CREATE UNIQUE NONCLUSTERED INDEX [UX_landing_J1AccountControlTotal_KeyBatch]
    ON [landing].[J1AccountControlTotal] ([IdNumber] ASC, [TermCode] ASC, [BatchId] DESC)
    INCLUDE ([RecordHash]);
GO

CREATE NONCLUSTERED INDEX [IX_landing_J1AccountControlTotal_BatchId]
    ON [landing].[J1AccountControlTotal] ([BatchId] ASC);
