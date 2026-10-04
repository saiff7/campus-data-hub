CREATE TABLE [J1Sim].[CredentialAwarded] (
    [CredentialAwardedId] BIGINT        NOT NULL,
    [IdNumber]            INT           NOT NULL,
    [ProgramCode]         VARCHAR (20)  NOT NULL,
    [TermCode]            VARCHAR (10)  NOT NULL,
    [AwardedDate]         DATE          NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3) CONSTRAINT [DF_J1Sim_CredentialAwarded_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3) CONSTRAINT [DF_J1Sim_CredentialAwarded_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_CredentialAwarded] PRIMARY KEY CLUSTERED ([CredentialAwardedId] ASC),
    CONSTRAINT [FK_J1Sim_CredentialAwarded_Student] FOREIGN KEY ([IdNumber]) REFERENCES [J1Sim].[Student] ([IdNumber]),
    CONSTRAINT [FK_J1Sim_CredentialAwarded_AcademicProgram] FOREIGN KEY ([ProgramCode]) REFERENCES [J1Sim].[AcademicProgram] ([ProgramCode]),
    CONSTRAINT [FK_J1Sim_CredentialAwarded_AcademicTerm] FOREIGN KEY ([TermCode]) REFERENCES [J1Sim].[AcademicTerm] ([TermCode]),
    CONSTRAINT [UQ_J1Sim_CredentialAwarded_StudentProgram] UNIQUE ([IdNumber], [ProgramCode])
);
