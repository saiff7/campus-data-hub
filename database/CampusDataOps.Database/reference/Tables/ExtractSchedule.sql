-- Which extracts each Agent schedule produces and how their reporting period is chosen
-- (docs/specifications/extract-controls.md); compliance.usp_RunScheduledExtracts reads it.
CREATE TABLE [reference].[ExtractSchedule] (
    [ScheduleCode]    VARCHAR (10)  NOT NULL,
    [ExtractTypeCode] VARCHAR (30)  NOT NULL,
    [PeriodRule]      VARCHAR (30)  NOT NULL,
    [SortOrder]       TINYINT       NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3) CONSTRAINT [DF_reference_ExtractSchedule_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3) CONSTRAINT [DF_reference_ExtractSchedule_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ExtractSchedule] PRIMARY KEY CLUSTERED ([ScheduleCode] ASC, [ExtractTypeCode] ASC),
    CONSTRAINT [FK_reference_ExtractSchedule_ExtractType]
        FOREIGN KEY ([ExtractTypeCode]) REFERENCES [reference].[ExtractType] ([ExtractTypeCode]),
    CONSTRAINT [CK_reference_ExtractSchedule_ScheduleCode]
        CHECK (([ScheduleCode] = 'DAILY' OR [ScheduleCode] = 'WEEKLY' OR [ScheduleCode] = 'CENSUS')),
    CONSTRAINT [CK_reference_ExtractSchedule_PeriodRule]
        CHECK (([PeriodRule] = 'TODAY' OR [PeriodRule] = 'CURRENT_ACADEMIC_YEAR' OR [PeriodRule] = 'CURRENT_TERM'
            OR [PeriodRule] = 'NONE' OR [PeriodRule] = 'NEW_SNAPSHOT_TERMS' OR [PeriodRule] = 'NEW_SNAPSHOT_FALL_TERMS'
            OR [PeriodRule] = 'LAST_COMPLETED_ACADEMIC_YEAR'))
);
