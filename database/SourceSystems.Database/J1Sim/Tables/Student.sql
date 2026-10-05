-- One active program per student is a deliberate simplification of the simulator.
CREATE TABLE [J1Sim].[Student] (
    [IdNumber]          INT           NOT NULL,
    [ProgramCode]       VARCHAR (20)  NOT NULL,
    [EntryTermCode]     VARCHAR (10)  NOT NULL,
    [StudentStatus]     VARCHAR (20)  NOT NULL,
    [ResidencyCode]     VARCHAR (20)  NOT NULL,
    [MatriculationDate] DATE          NOT NULL,
    [CreatedAtUtc]      DATETIME2 (3) CONSTRAINT [DF_J1Sim_Student_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]      DATETIME2 (3) CONSTRAINT [DF_J1Sim_Student_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_Student] PRIMARY KEY CLUSTERED ([IdNumber] ASC),
    CONSTRAINT [FK_J1Sim_Student_Person] FOREIGN KEY ([IdNumber]) REFERENCES [J1Sim].[Person] ([IdNumber]),
    CONSTRAINT [FK_J1Sim_Student_AcademicProgram] FOREIGN KEY ([ProgramCode]) REFERENCES [J1Sim].[AcademicProgram] ([ProgramCode]),
    CONSTRAINT [FK_J1Sim_Student_EntryTerm] FOREIGN KEY ([EntryTermCode]) REFERENCES [J1Sim].[AcademicTerm] ([TermCode]),
    CONSTRAINT [CK_J1Sim_Student_StudentStatus]
        CHECK (([StudentStatus] = 'ACTIVE' OR [StudentStatus] = 'INACTIVE' OR [StudentStatus] = 'GRADUATED'
            OR [StudentStatus] = 'WITHDRAWN')),
    CONSTRAINT [CK_J1Sim_Student_ResidencyCode]
        CHECK (([ResidencyCode] = 'IN_STATE' OR [ResidencyCode] = 'OUT_OF_STATE' OR [ResidencyCode] = 'INTERNATIONAL'))
);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_Student_ProgramCode]
    ON [J1Sim].[Student] ([ProgramCode] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_Student_EntryTermCode]
    ON [J1Sim].[Student] ([EntryTermCode] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_Student_UpdatedAtUtc]
    ON [J1Sim].[Student] ([UpdatedAtUtc] ASC);
