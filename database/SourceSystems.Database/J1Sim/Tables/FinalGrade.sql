-- GradePoints is NULL for grades that do not count toward GPA (W, I).
CREATE TABLE [J1Sim].[FinalGrade] (
    [EnrollmentId] BIGINT         NOT NULL,
    [GradeCode]    VARCHAR (2)    NOT NULL,
    [GradePoints]  DECIMAL (3, 2) NULL,
    [PostedAtUtc]  DATETIME2 (3)  NOT NULL,
    [CreatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_J1Sim_FinalGrade_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_J1Sim_FinalGrade_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_FinalGrade] PRIMARY KEY CLUSTERED ([EnrollmentId] ASC),
    CONSTRAINT [FK_J1Sim_FinalGrade_Enrollment] FOREIGN KEY ([EnrollmentId]) REFERENCES [J1Sim].[Enrollment] ([EnrollmentId]),
    CONSTRAINT [CK_J1Sim_FinalGrade_GradeCode]
        CHECK (([GradeCode] = 'A' OR [GradeCode] = 'A-' OR [GradeCode] = 'B+' OR [GradeCode] = 'B' OR [GradeCode] = 'B-' OR [GradeCode] = 'C+' OR [GradeCode] = 'C' OR [GradeCode] = 'C-' OR [GradeCode] = 'D+' OR [GradeCode] = 'D' OR [GradeCode] = 'F' OR [GradeCode] = 'W' OR [GradeCode] = 'I')),
    CONSTRAINT [CK_J1Sim_FinalGrade_GradePoints]
        CHECK ((([GradeCode] = 'W' OR [GradeCode] = 'I') AND [GradePoints] IS NULL)
            OR (NOT ([GradeCode] = 'W' OR [GradeCode] = 'I') AND ([GradePoints] >= 0 AND [GradePoints] <= 4)))
);
