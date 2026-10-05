-- Mutually exclusive per-application outcomes of one reconciliation run.
CREATE TABLE [reference].[ReconciliationOutcome] (
    [OutcomeCode]  VARCHAR (20)   NOT NULL,
    [Description]  NVARCHAR (400) NOT NULL,
    [SortOrder]    TINYINT        NOT NULL,
    [CreatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_reference_ReconciliationOutcome_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_reference_ReconciliationOutcome_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ReconciliationOutcome] PRIMARY KEY CLUSTERED ([OutcomeCode] ASC),
    CONSTRAINT [UQ_reference_ReconciliationOutcome_SortOrder] UNIQUE ([SortOrder])
);
