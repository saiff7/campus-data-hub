-- Governed copy of the SIS program catalog for reporting. It must agree with J1Sim.AcademicProgram;
-- a database test enforces that agreement after seeding. IpedsAwardLevel follows the IPEDS
-- Completions award levels for a semester-credit institution (docs/specifications/ipeds-measure-mapping.md):
-- associate degree 3; certificate of 30-59 credits 2; certificate of 9-29 credits 1b.
CREATE TABLE [reference].[AcademicProgram] (
    [ProgramCode]     VARCHAR (20)   NOT NULL,
    [ProgramName]     NVARCHAR (150) NOT NULL,
    [CredentialLevel] VARCHAR (20)   NOT NULL,
    [CipCode]         CHAR (7)       NOT NULL,
    [RequiredCredits] DECIMAL (5, 1) NOT NULL,
    [IpedsAwardLevel] VARCHAR (3)    NOT NULL,
    [DivisionCode]    VARCHAR (30)   NOT NULL,
    [IsActive]        BIT            NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_reference_AcademicProgram_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_reference_AcademicProgram_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_AcademicProgram] PRIMARY KEY CLUSTERED ([ProgramCode] ASC),
    CONSTRAINT [FK_reference_AcademicProgram_AcademicDivision]
        FOREIGN KEY ([DivisionCode]) REFERENCES [reference].[AcademicDivision] ([DivisionCode]),
    CONSTRAINT [CK_reference_AcademicProgram_CipCode] CHECK ([CipCode] LIKE '[0-9][0-9].[0-9][0-9][0-9][0-9]'),
    CONSTRAINT [CK_reference_AcademicProgram_AwardLevel]
        CHECK (([CredentialLevel] = 'ASSOCIATE' AND [IpedsAwardLevel] = '3')
            OR ([CredentialLevel] = 'CERTIFICATE' AND [IpedsAwardLevel] = '2'
                AND [RequiredCredits] >= 30 AND [RequiredCredits] < 60)
            OR ([CredentialLevel] = 'CERTIFICATE' AND [IpedsAwardLevel] = '1b'
                AND [RequiredCredits] >= 9 AND [RequiredCredits] < 30))
);
