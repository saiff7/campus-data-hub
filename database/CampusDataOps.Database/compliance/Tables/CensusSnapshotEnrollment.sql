-- One row per person and term in a census snapshot (docs/specifications/report-catalog.md R1).
-- Immutable: the trigger rejects every update and delete. Row-level security
-- (security.ProgramScopePolicy) filters it for program coordinators. The inclusion check names
-- IS NOT NULL explicitly: a CHECK passes when its condition is UNKNOWN.
CREATE TABLE [compliance].[CensusSnapshotEnrollment] (
    [CensusSnapshotId]    INT            NOT NULL,
    [IdNumber]            INT            NOT NULL,
    [ProgramCode]         VARCHAR (20)   NULL,
    [EntryTermCode]       VARCHAR (10)   NULL,
    [StudentStatus]       VARCHAR (20)   NULL,
    [ResidencyCode]       VARCHAR (20)   NULL,
    [CensusCredits]       DECIMAL (5, 1) NOT NULL,
    [CountedSections]     SMALLINT       NOT NULL,
    [AttendanceIntensity] VARCHAR (10)   NULL,
    [EntryStatus]         VARCHAR (10)   NULL,
    [AgeAtCensus]         TINYINT        NULL,
    [IsCensusIncluded]    BIT            NOT NULL,
    [ExclusionReason]     VARCHAR (30)   NULL,
    CONSTRAINT [PK_compliance_CensusSnapshotEnrollment] PRIMARY KEY CLUSTERED ([CensusSnapshotId] ASC, [IdNumber] ASC),
    CONSTRAINT [FK_compliance_CensusSnapshotEnrollment_Snapshot]
        FOREIGN KEY ([CensusSnapshotId]) REFERENCES [compliance].[CensusSnapshot] ([CensusSnapshotId]),
    CONSTRAINT [CK_compliance_CensusSnapshotEnrollment_Inclusion]
        CHECK (([IsCensusIncluded] = 1 AND [ExclusionReason] IS NULL AND [CensusCredits] > 0
                AND ([AttendanceIntensity] = 'FULL_TIME' OR [AttendanceIntensity] = 'PART_TIME'))
            OR ([IsCensusIncluded] = 0 AND [AttendanceIntensity] IS NULL AND [ExclusionReason] IS NOT NULL
                AND ([ExclusionReason] = 'NO_STUDENT_RECORD' OR [ExclusionReason] = 'DROPPED_BEFORE_CENSUS'
                    OR [ExclusionReason] = 'REGISTERED_AFTER_CENSUS'))),
    CONSTRAINT [CK_compliance_CensusSnapshotEnrollment_EntryStatus]
        CHECK ([EntryStatus] IS NULL OR [EntryStatus] = 'ENTERING' OR [EntryStatus] = 'CONTINUING')
);
GO

CREATE NONCLUSTERED INDEX [IX_compliance_CensusSnapshotEnrollment_SnapshotProgram]
    ON [compliance].[CensusSnapshotEnrollment] ([CensusSnapshotId] ASC, [ProgramCode] ASC)
    INCLUDE ([IsCensusIncluded], [AttendanceIntensity], [CensusCredits]);
GO

CREATE TRIGGER [compliance].[trg_CensusSnapshotEnrollment_Immutable]
ON [compliance].[CensusSnapshotEnrollment]
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 52010, N'Census snapshots are immutable (ADR-003); capture a new rule version instead.', 1;
END;
