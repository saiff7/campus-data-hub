CREATE TABLE [J1Sim].[AcademicTerm] (
    [TermCode]           VARCHAR (10)   NOT NULL,
    [TermName]           NVARCHAR (50)  NOT NULL,
    [AcademicYear]       CHAR (9)       NOT NULL,
    [StartDate]          DATE           NOT NULL,
    [CensusDate]         DATE           NOT NULL,
    [EndDate]            DATE           NOT NULL,
    [IsOpenForAdmission] BIT            NOT NULL,
    [CreatedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_J1Sim_AcademicTerm_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_J1Sim_AcademicTerm_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_AcademicTerm] PRIMARY KEY CLUSTERED ([TermCode] ASC),
    CONSTRAINT [UQ_J1Sim_AcademicTerm_TermName] UNIQUE ([TermName]),
    CONSTRAINT [CK_J1Sim_AcademicTerm_DateOrder] CHECK ([StartDate] <= [CensusDate] AND [CensusDate] <= [EndDate]),
    CONSTRAINT [CK_J1Sim_AcademicTerm_AcademicYear] CHECK ([AcademicYear] LIKE '[12][0-9][0-9][0-9]-[12][0-9][0-9][0-9]')
);
