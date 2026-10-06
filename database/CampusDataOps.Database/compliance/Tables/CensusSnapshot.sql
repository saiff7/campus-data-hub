-- One immutable census snapshot per term and rule version (ADR-003). The header records what
-- the snapshot was built from and a checksum of its rows; compliance.usp_VerifyCensusSnapshot
-- recomputes it. The trigger below rejects every update and delete.
CREATE TABLE [compliance].[CensusSnapshot] (
    [CensusSnapshotId]   INT           IDENTITY (1, 1) NOT NULL,
    [TermCode]           VARCHAR (10)  NOT NULL,
    [CensusDate]         DATE          NOT NULL,
    [RuleVersion]        VARCHAR (20)  NOT NULL,
    [SourceBatchId]      BIGINT        NOT NULL,
    [SourceWatermarkUtc] DATETIME2 (3) NULL,
    [CapturedAtUtc]      DATETIME2 (3) NOT NULL,
    [CapturedBy]         NVARCHAR (128) NOT NULL,
    [PopulationCount]    INT           NOT NULL,
    [IncludedCount]      INT           NOT NULL,
    [FullTimeCount]      INT           NOT NULL,
    [CreditTotal]        DECIMAL (9, 1) NOT NULL,
    [RowChecksum]        BINARY (32)   NOT NULL,
    [CaptureLagDays]     AS (DATEDIFF(DAY, [CensusDate], CAST([CapturedAtUtc] AS DATE))) PERSISTED,
    CONSTRAINT [PK_compliance_CensusSnapshot] PRIMARY KEY CLUSTERED ([CensusSnapshotId] ASC),
    CONSTRAINT [UQ_compliance_CensusSnapshot_TermRule] UNIQUE ([TermCode], [RuleVersion]),
    CONSTRAINT [FK_compliance_CensusSnapshot_Term] FOREIGN KEY ([TermCode]) REFERENCES [reference].[AcademicTerm] ([TermCode]),
    CONSTRAINT [FK_compliance_CensusSnapshot_RuleVersion]
        FOREIGN KEY ([RuleVersion]) REFERENCES [compliance].[CensusRuleVersion] ([RuleVersion]),
    CONSTRAINT [FK_compliance_CensusSnapshot_SourceBatch] FOREIGN KEY ([SourceBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [CK_compliance_CensusSnapshot_Counts]
        CHECK ([IncludedCount] >= 0 AND [IncludedCount] <= [PopulationCount] AND [FullTimeCount] <= [IncludedCount] AND [CreditTotal] >= 0),
    CONSTRAINT [CK_compliance_CensusSnapshot_CapturedAfterCensus] CHECK (CAST([CapturedAtUtc] AS DATE) >= [CensusDate])
);
GO

CREATE TRIGGER [compliance].[trg_CensusSnapshot_Immutable]
ON [compliance].[CensusSnapshot]
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 52010, N'Census snapshots are immutable (ADR-003); capture a new rule version instead.', 1;
END;
