-- One row per J1-Sim enrollment per version received, with section and final grade.
-- Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest
-- landed version of the same key; one version per key per batch is database-enforced.
CREATE TABLE [landing].[J1EnrollmentRaw] (
    [LandingRowId]       BIGINT            IDENTITY (1, 1) NOT NULL,
    [BatchId]            BIGINT            NOT NULL,
    [SourceSystemCode]   VARCHAR (20)      NOT NULL
        CONSTRAINT [DF_landing_J1EnrollmentRaw_SourceSystemCode] DEFAULT ('J1_SIM'),
    [EnrollmentId]       BIGINT            NOT NULL,
    [IdNumber]           INT               NOT NULL,
    [CourseSectionId]    INT               NOT NULL,
    [TermCode]           VARCHAR (10)      NOT NULL,
    [SubjectCode]        VARCHAR (6)       NOT NULL,
    [CourseNumber]       VARCHAR (6)       NOT NULL,
    [SectionNumber]      VARCHAR (4)       NOT NULL,
    [CreditHours]        DECIMAL (4, 1)    NOT NULL,
    [RegistrationStatus] VARCHAR (15)      NOT NULL,
    [RegisteredAtUtc]    DATETIME2 (3)     NOT NULL,
    [StatusChangedAtUtc] DATETIME2 (3)     NOT NULL,
    [GradeCode]          VARCHAR (2)       NULL,
    [GradePoints]        DECIMAL (3, 2)    NULL,
    [GradePostedAtUtc]   DATETIME2 (3)     NULL,
    [SourceRecordId]     AS (CONVERT(VARCHAR (64), [EnrollmentId])) PERSISTED NOT NULL,
    [SourceUpdatedAtUtc] DATETIME2 (3)     NOT NULL,
    [RecordHash]         BINARY (32)       NOT NULL,
    [RequestId]          VARCHAR (100)     NOT NULL,
    [IngestedAtUtc]      DATETIME2 (3)     NOT NULL
        CONSTRAINT [DF_landing_J1EnrollmentRaw_IngestedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_landing_J1EnrollmentRaw] PRIMARY KEY CLUSTERED ([LandingRowId] ASC),
    CONSTRAINT [FK_landing_J1EnrollmentRaw_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_landing_J1EnrollmentRaw_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [CK_landing_J1EnrollmentRaw_SourceSystemCode] CHECK ([SourceSystemCode] = 'J1_SIM')
);
GO

-- Serves the latest-version lookup (TOP 1 ... ORDER BY BatchId DESC) and enforces one
-- version per key per batch.
CREATE UNIQUE NONCLUSTERED INDEX [UX_landing_J1EnrollmentRaw_KeyBatch]
    ON [landing].[J1EnrollmentRaw] ([EnrollmentId] ASC, [BatchId] DESC)
    INCLUDE ([RecordHash]);
GO

CREATE NONCLUSTERED INDEX [IX_landing_J1EnrollmentRaw_BatchId]
    ON [landing].[J1EnrollmentRaw] ([BatchId] ASC);
