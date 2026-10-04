CREATE TABLE [J1Sim].[Enrollment] (
    [EnrollmentId]       BIGINT        NOT NULL,
    [IdNumber]           INT           NOT NULL,
    [CourseSectionId]    INT           NOT NULL,
    [RegistrationStatus] VARCHAR (15)  NOT NULL,
    [RegisteredAtUtc]    DATETIME2 (3) NOT NULL,
    [StatusChangedAtUtc] DATETIME2 (3) NOT NULL,
    [CreatedAtUtc]       DATETIME2 (3) CONSTRAINT [DF_J1Sim_Enrollment_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]       DATETIME2 (3) CONSTRAINT [DF_J1Sim_Enrollment_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_Enrollment] PRIMARY KEY CLUSTERED ([EnrollmentId] ASC),
    CONSTRAINT [FK_J1Sim_Enrollment_Student] FOREIGN KEY ([IdNumber]) REFERENCES [J1Sim].[Student] ([IdNumber]),
    CONSTRAINT [FK_J1Sim_Enrollment_CourseSection] FOREIGN KEY ([CourseSectionId]) REFERENCES [J1Sim].[CourseSection] ([CourseSectionId]),
    CONSTRAINT [UQ_J1Sim_Enrollment_StudentSection] UNIQUE ([IdNumber], [CourseSectionId]),
    CONSTRAINT [CK_J1Sim_Enrollment_RegistrationStatus] CHECK (([RegistrationStatus] = 'REGISTERED' OR [RegistrationStatus] = 'DROPPED' OR [RegistrationStatus] = 'WITHDRAWN')),
    CONSTRAINT [CK_J1Sim_Enrollment_StatusAfterRegistration] CHECK ([StatusChangedAtUtc] >= [RegisteredAtUtc])
);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_Enrollment_CourseSectionId]
    ON [J1Sim].[Enrollment] ([CourseSectionId] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_Enrollment_UpdatedAtUtc]
    ON [J1Sim].[Enrollment] ([UpdatedAtUtc] ASC);
