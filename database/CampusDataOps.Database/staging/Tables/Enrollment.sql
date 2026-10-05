CREATE TABLE [staging].[Enrollment] (
    [EnrollmentId]       BIGINT         NOT NULL,
    [LandingRowId]       BIGINT         NOT NULL,
    [IdNumber]           INT            NOT NULL,
    [CourseSectionId]    INT            NOT NULL,
    [TermCode]           VARCHAR (10)   NOT NULL,
    [SubjectCode]        VARCHAR (6)    NOT NULL,
    [CourseNumber]       VARCHAR (6)    NOT NULL,
    [SectionNumber]      VARCHAR (4)    NOT NULL,
    [CreditHours]        DECIMAL (4, 1) NOT NULL,
    [RegistrationStatus] VARCHAR (15)   NOT NULL,
    [RegisteredAtUtc]    DATETIME2 (3)  NOT NULL,
    [StatusChangedAtUtc] DATETIME2 (3)  NOT NULL,
    [GradeCode]          VARCHAR (2)    NULL,
    [GradePoints]        DECIMAL (3, 2) NULL,
    [GradePostedAtUtc]   DATETIME2 (3)  NULL,
    [LastStagedBatchId]  BIGINT         NOT NULL,
    [CreatedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_staging_Enrollment_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_staging_Enrollment_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_staging_Enrollment] PRIMARY KEY CLUSTERED ([EnrollmentId] ASC),
    CONSTRAINT [FK_staging_Enrollment_LandingRow] FOREIGN KEY ([LandingRowId]) REFERENCES [landing].[J1EnrollmentRaw] ([LandingRowId]),
    CONSTRAINT [FK_staging_Enrollment_LastStagedBatch] FOREIGN KEY ([LastStagedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId])
);
GO

CREATE NONCLUSTERED INDEX [IX_staging_Enrollment_StudentTerm]
    ON [staging].[Enrollment] ([IdNumber] ASC, [TermCode] ASC)
    INCLUDE ([RegistrationStatus]);
