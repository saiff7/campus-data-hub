CREATE TABLE [J1Sim].[CourseSection] (
    [CourseSectionId] INT            NOT NULL,
    [TermCode]        VARCHAR (10)   NOT NULL,
    [SubjectCode]     VARCHAR (6)    NOT NULL,
    [CourseNumber]    VARCHAR (6)    NOT NULL,
    [SectionNumber]   VARCHAR (4)    NOT NULL,
    [CourseTitle]     NVARCHAR (150) NOT NULL,
    [CreditHours]     DECIMAL (4, 1) NOT NULL,
    [Capacity]        SMALLINT       NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_J1Sim_CourseSection_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_J1Sim_CourseSection_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_CourseSection] PRIMARY KEY CLUSTERED ([CourseSectionId] ASC),
    CONSTRAINT [FK_J1Sim_CourseSection_AcademicTerm] FOREIGN KEY ([TermCode]) REFERENCES [J1Sim].[AcademicTerm] ([TermCode]),
    CONSTRAINT [UQ_J1Sim_CourseSection_NaturalKey] UNIQUE ([TermCode], [SubjectCode], [CourseNumber], [SectionNumber]),
    CONSTRAINT [CK_J1Sim_CourseSection_CreditHours] CHECK ([CreditHours] > 0 AND [CreditHours] <= 12),
    CONSTRAINT [CK_J1Sim_CourseSection_Capacity] CHECK ([Capacity] > 0)
);
