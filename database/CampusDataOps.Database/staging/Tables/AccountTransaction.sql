CREATE TABLE [staging].[AccountTransaction] (
    [TransactionId]     BIGINT          NOT NULL,
    [LandingRowId]      BIGINT          NOT NULL,
    [IdNumber]          INT             NOT NULL,
    [TermCode]          VARCHAR (10)    NOT NULL,
    [TransactionType]   VARCHAR (12)    NOT NULL,
    [DetailCode]        VARCHAR (10)    NOT NULL,
    [Amount]            DECIMAL (12, 2) NOT NULL,
    [PostedDate]        DATE            NOT NULL,
    [DueDate]           DATE            NULL,
    [LastStagedBatchId] BIGINT          NOT NULL,
    [CreatedAtUtc]      DATETIME2 (3)   CONSTRAINT [DF_staging_AccountTransaction_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]      DATETIME2 (3)   CONSTRAINT [DF_staging_AccountTransaction_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_staging_AccountTransaction] PRIMARY KEY CLUSTERED ([TransactionId] ASC),
    CONSTRAINT [FK_staging_AccountTransaction_LandingRow]
        FOREIGN KEY ([LandingRowId]) REFERENCES [landing].[J1AccountTransactionRaw] ([LandingRowId]),
    CONSTRAINT [FK_staging_AccountTransaction_LastStagedBatch]
        FOREIGN KEY ([LastStagedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId])
);
GO

CREATE NONCLUSTERED INDEX [IX_staging_AccountTransaction_StudentTerm]
    ON [staging].[AccountTransaction] ([IdNumber] ASC, [TermCode] ASC)
    INCLUDE ([Amount]);
