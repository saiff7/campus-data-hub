-- Governed term calendar used by integration and compliance. It must agree with the
-- J1-Sim term table; a database test enforces that agreement after seeding.
-- Summer terms belong to the academic year of the preceding fall (project assumption,
-- documented in the business glossary).
CREATE TABLE [reference].[AcademicTerm] (
    [TermCode]           VARCHAR (10)  NOT NULL,
    [TermName]           NVARCHAR (50) NOT NULL,
    [TermType]           VARCHAR (10)  NOT NULL,
    [AcademicYear]       CHAR (9)      NOT NULL,
    [StartDate]          DATE          NOT NULL,
    [CensusDate]         DATE          NOT NULL,
    [EndDate]            DATE          NOT NULL,
    [IsOpenForAdmission] BIT           NOT NULL,
    [CreatedAtUtc]       DATETIME2 (3) CONSTRAINT [DF_reference_AcademicTerm_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]       DATETIME2 (3) CONSTRAINT [DF_reference_AcademicTerm_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_AcademicTerm] PRIMARY KEY CLUSTERED ([TermCode] ASC),
    CONSTRAINT [UQ_reference_AcademicTerm_TermName] UNIQUE ([TermName]),
    CONSTRAINT [CK_reference_AcademicTerm_TermType] CHECK (([TermType] = 'FALL' OR [TermType] = 'SPRING' OR [TermType] = 'SUMMER')),
    CONSTRAINT [CK_reference_AcademicTerm_DateOrder] CHECK ([StartDate] <= [CensusDate] AND [CensusDate] <= [EndDate]),
    CONSTRAINT [CK_reference_AcademicTerm_AcademicYear] CHECK ([AcademicYear] LIKE '[12][0-9][0-9][0-9]-[12][0-9][0-9][0-9]')
);
