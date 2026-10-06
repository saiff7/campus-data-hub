-- Current state of each J1-Sim credential award (certificate or associate degree).
CREATE TABLE [staging].[CredentialAwarded] (
    [CredentialAwardedId] BIGINT        NOT NULL,
    [LandingRowId]        BIGINT        NOT NULL,
    [IdNumber]            INT           NOT NULL,
    [ProgramCode]         VARCHAR (20)  NOT NULL,
    [TermCode]            VARCHAR (10)  NOT NULL,
    [AwardedDate]         DATE          NOT NULL,
    [LastStagedBatchId]   BIGINT        NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3) CONSTRAINT [DF_staging_CredentialAwarded_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3) CONSTRAINT [DF_staging_CredentialAwarded_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_staging_CredentialAwarded] PRIMARY KEY CLUSTERED ([CredentialAwardedId] ASC),
    CONSTRAINT [FK_staging_CredentialAwarded_LandingRow]
        FOREIGN KEY ([LandingRowId]) REFERENCES [landing].[J1CredentialRaw] ([LandingRowId]),
    CONSTRAINT [FK_staging_CredentialAwarded_LastStagedBatch]
        FOREIGN KEY ([LastStagedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId])
);
GO
CREATE NONCLUSTERED INDEX [IX_staging_CredentialAwarded_StudentProgram]
    ON [staging].[CredentialAwarded] ([IdNumber] ASC, [ProgramCode] ASC)
    INCLUDE ([TermCode], [AwardedDate]);
GO
CREATE NONCLUSTERED INDEX [IX_staging_CredentialAwarded_AwardedDate]
    ON [staging].[CredentialAwarded] ([AwardedDate] ASC);
