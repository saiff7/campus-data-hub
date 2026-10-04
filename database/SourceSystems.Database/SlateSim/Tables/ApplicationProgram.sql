-- ProgramCode is CRM free text; validity is decided against J1-Sim during integration.
-- An application with no ChoiceRank 1 row is a "missing program" case.
CREATE TABLE [SlateSim].[ApplicationProgram] (
    [ApplicationProgramId] BIGINT           NOT NULL,
    [ApplicationId]        UNIQUEIDENTIFIER NOT NULL,
    [ProgramCode]          VARCHAR (20)     NOT NULL,
    [ChoiceRank]           TINYINT          NOT NULL,
    [CreatedAtUtc]         DATETIME2 (3)    CONSTRAINT [DF_SlateSim_ApplicationProgram_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]         DATETIME2 (3)    CONSTRAINT [DF_SlateSim_ApplicationProgram_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_SlateSim_ApplicationProgram] PRIMARY KEY CLUSTERED ([ApplicationProgramId] ASC),
    CONSTRAINT [FK_SlateSim_ApplicationProgram_Application]
        FOREIGN KEY ([ApplicationId]) REFERENCES [SlateSim].[Application] ([ApplicationId]),
    CONSTRAINT [CK_SlateSim_ApplicationProgram_ChoiceRank] CHECK (([ChoiceRank] >= 1 AND [ChoiceRank] <= 3)),
    CONSTRAINT [UQ_SlateSim_ApplicationProgram_ApplicationChoice] UNIQUE ([ApplicationId], [ChoiceRank])
);
