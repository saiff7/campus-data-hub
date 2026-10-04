-- Maps admissions (Slate-Sim) program codes to SIS (J1-Sim) program codes. A Slate code
-- absent from this table, or mapped to an inactive SIS program, cannot be integrated.
CREATE TABLE [reference].[ProgramCrosswalk] (
    [SlateProgramCode] VARCHAR (20)   NOT NULL,
    [J1ProgramCode]    VARCHAR (20)   NOT NULL,
    [ProgramName]      NVARCHAR (150) NOT NULL,
    [CredentialLevel]  VARCHAR (20)   NOT NULL,
    [CipCode]          CHAR (7)       NOT NULL,
    [IsActive]         BIT            NOT NULL,
    [EffectiveFrom]    DATE           NOT NULL,
    [EffectiveTo]      DATE           NULL,
    [CreatedAtUtc]     DATETIME2 (3)  CONSTRAINT [DF_reference_ProgramCrosswalk_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]     DATETIME2 (3)  CONSTRAINT [DF_reference_ProgramCrosswalk_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ProgramCrosswalk] PRIMARY KEY CLUSTERED ([SlateProgramCode] ASC),
    CONSTRAINT [UQ_reference_ProgramCrosswalk_J1ProgramCode] UNIQUE ([J1ProgramCode]),
    CONSTRAINT [CK_reference_ProgramCrosswalk_CredentialLevel]
        CHECK (([CredentialLevel] = 'CERTIFICATE' OR [CredentialLevel] = 'ASSOCIATE')),
    CONSTRAINT [CK_reference_ProgramCrosswalk_CipCode] CHECK ([CipCode] LIKE '[0-9][0-9].[0-9][0-9][0-9][0-9]'),
    CONSTRAINT [CK_reference_ProgramCrosswalk_EffectiveRange] CHECK ([EffectiveTo] IS NULL OR [EffectiveTo] >= [EffectiveFrom])
);
