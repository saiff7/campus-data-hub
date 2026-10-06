CREATE TABLE [staging].[FinancialAidAward] (
    [AwardId]           BIGINT          NOT NULL,
    [LandingRowId]      BIGINT          NOT NULL,
    [IdNumber]          INT             NOT NULL,
    [AidYear]           CHAR (9)        NOT NULL,
    [TermCode]          VARCHAR (10)    NOT NULL,
    [FundCode]          VARCHAR (15)    NOT NULL,
    [AwardStatus]       VARCHAR (10)    NOT NULL,
    [OfferedAmount]     DECIMAL (12, 2) NOT NULL,
    [AcceptedAmount]    DECIMAL (12, 2) NOT NULL,
    [DisbursedAmount]   DECIMAL (12, 2) NOT NULL,
    [LastStagedBatchId] BIGINT          NOT NULL,
    [CreatedAtUtc]      DATETIME2 (3)   CONSTRAINT [DF_staging_FinancialAidAward_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]      DATETIME2 (3)   CONSTRAINT [DF_staging_FinancialAidAward_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_staging_FinancialAidAward] PRIMARY KEY CLUSTERED ([AwardId] ASC),
    CONSTRAINT [FK_staging_FinancialAidAward_LandingRow]
        FOREIGN KEY ([LandingRowId]) REFERENCES [landing].[J1FinancialAidRaw] ([LandingRowId]),
    CONSTRAINT [FK_staging_FinancialAidAward_LastStagedBatch]
        FOREIGN KEY ([LastStagedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId])
);
GO

CREATE NONCLUSTERED INDEX [IX_staging_FinancialAidAward_StudentTerm]
    ON [staging].[FinancialAidAward] ([IdNumber] ASC, [TermCode] ASC);
