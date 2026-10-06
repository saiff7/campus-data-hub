-- R1 Enrollment census extract (docs/specifications/report-catalog.md). Reads only immutable
-- snapshots captured under the current census rule version; never live data (ADR-003).
-- Grain: one row per student per term.
CREATE VIEW [reporting].[vw_EnrollmentCensus]
AS
SELECT
    s.[CensusSnapshotId],
    s.[TermCode],
    s.[CensusDate],
    s.[RuleVersion],
    e.[IdNumber],
    e.[ProgramCode],
    p.[ProgramName],
    p.[CredentialLevel],
    e.[EntryTermCode],
    e.[ResidencyCode],
    e.[CensusCredits],
    e.[CountedSections],
    e.[AttendanceIntensity],
    e.[EntryStatus],
    e.[AgeAtCensus],
    e.[IsCensusIncluded],
    e.[ExclusionReason]
FROM [compliance].[CensusSnapshot] AS s
INNER JOIN [compliance].[CensusRuleVersion] AS r
    ON s.[RuleVersion] = r.[RuleVersion]
   AND r.[IsCurrent] = 1
INNER JOIN [compliance].[CensusSnapshotEnrollment] AS e ON s.[CensusSnapshotId] = e.[CensusSnapshotId]
LEFT JOIN [reference].[AcademicProgram] AS p ON e.[ProgramCode] = p.[ProgramCode];
