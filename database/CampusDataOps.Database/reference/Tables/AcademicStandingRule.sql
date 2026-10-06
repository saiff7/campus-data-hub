-- Academic standing by cumulative GPA (project assumption; docs/specifications/report-catalog.md R4).
-- A student without GPA credits is NOT_EVALUATED, which needs no range here.
CREATE TABLE [reference].[AcademicStandingRule] (
    [StandingCode]              VARCHAR (20)   NOT NULL,
    [Description]               NVARCHAR (200) NOT NULL,
    [MinCumulativeGpa]          DECIMAL (3, 2) NOT NULL,
    [MaxCumulativeGpaExclusive] DECIMAL (3, 2) NULL,
    [CreatedAtUtc]              DATETIME2 (3)  NOT NULL
        CONSTRAINT [DF_reference_AcademicStandingRule_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
    [UpdatedAtUtc]              DATETIME2 (3)  NOT NULL
        CONSTRAINT [DF_reference_AcademicStandingRule_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_reference_AcademicStandingRule] PRIMARY KEY CLUSTERED ([StandingCode] ASC),
    CONSTRAINT [CK_reference_AcademicStandingRule_Range]
        CHECK ([MinCumulativeGpa] >= 0 AND ([MaxCumulativeGpaExclusive] IS NULL OR [MaxCumulativeGpaExclusive] > [MinCumulativeGpa]))
);
