CREATE TABLE [J1Sim].[AcademicProgram] (
    [ProgramCode]     VARCHAR (20)   NOT NULL,
    [ProgramName]     NVARCHAR (150) NOT NULL,
    [CredentialLevel] VARCHAR (20)   NOT NULL,
    [CipCode]         CHAR (7)       NOT NULL,
    [RequiredCredits] DECIMAL (5, 1) NOT NULL,
    [IsActive]        BIT            NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_J1Sim_AcademicProgram_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_J1Sim_AcademicProgram_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_AcademicProgram] PRIMARY KEY CLUSTERED ([ProgramCode] ASC),
    CONSTRAINT [CK_J1Sim_AcademicProgram_CredentialLevel] CHECK (([CredentialLevel] = 'CERTIFICATE' OR [CredentialLevel] = 'ASSOCIATE')),
    CONSTRAINT [CK_J1Sim_AcademicProgram_CipCode] CHECK ([CipCode] LIKE '[0-9][0-9].[0-9][0-9][0-9][0-9]'),
    CONSTRAINT [CK_J1Sim_AcademicProgram_RequiredCredits] CHECK ([RequiredCredits] > 0)
);
