-- One row per J1-Sim financial aid award per version received.
-- Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest
-- landed version of the same key; one version per key per batch is database-enforced.
CREATE TABLE [landing].[J1FinancialAidRaw] (
    [LandingRowId]       BIGINT            IDENTITY (1, 1) NOT NULL,
    [BatchId]            BIGINT            NOT NULL,
    [SourceSystemCode]   VARCHAR (20)      NOT NULL
        CONSTRAINT [DF_landing_J1FinancialAidRaw_SourceSystemCode] DEFAULT ('J1_SIM'),
    [AwardId]            BIGINT            NOT NULL,
    [IdNumber]           INT               NOT NULL,
    [AidYear]            CHAR (9)          NOT NULL,
    [TermCode]           VARCHAR (10)      NOT NULL,
    [FundCode]           VARCHAR (15)      NOT NULL,
    [AwardStatus]        VARCHAR (10)      NOT NULL,
    [OfferedAmount]      DECIMAL (12, 2)   NOT NULL,
    [AcceptedAmount]     DECIMAL (12, 2)   NOT NULL,
    [DisbursedAmount]    DECIMAL (12, 2)   NOT NULL,
    [SourceRecordId]     AS (CONVERT(VARCHAR (64), [AwardId])) PERSISTED NOT NULL,
    [SourceUpdatedAtUtc] DATETIME2 (3)     NOT NULL,
    [RecordHash]         BINARY (32)       NOT NULL,
    [RequestId]          VARCHAR (100)     NOT NULL,
    [IngestedAtUtc]      DATETIME2 (3)     NOT NULL
        CONSTRAINT [DF_landing_J1FinancialAidRaw_IngestedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_landing_J1FinancialAidRaw] PRIMARY KEY CLUSTERED ([LandingRowId] ASC),
    CONSTRAINT [FK_landing_J1FinancialAidRaw_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_landing_J1FinancialAidRaw_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [CK_landing_J1FinancialAidRaw_SourceSystemCode] CHECK ([SourceSystemCode] = 'J1_SIM')
);
GO

-- Serves the latest-version lookup (TOP 1 ... ORDER BY BatchId DESC) and enforces one
-- version per key per batch.
CREATE UNIQUE NONCLUSTERED INDEX [UX_landing_J1FinancialAidRaw_KeyBatch]
    ON [landing].[J1FinancialAidRaw] ([AwardId] ASC, [BatchId] DESC)
    INCLUDE ([RecordHash]);
GO

CREATE NONCLUSTERED INDEX [IX_landing_J1FinancialAidRaw_BatchId]
    ON [landing].[J1FinancialAidRaw] ([BatchId] ASC);
