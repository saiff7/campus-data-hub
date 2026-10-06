-- Masked census roster for program coordinators (docs/architecture/security-model.md). Row-level
-- security on compliance.CensusSnapshotEnrollment limits each coordinator to their programs.
-- Grain: one row per student per term, current census rule version only.
CREATE VIEW [reporting].[vw_ProgramCensusRoster]
AS
SELECT
    s.[TermCode],
    s.[CensusDate],
    e.[ProgramCode],
    sp.[MaskedStudentId],
    e.[CensusCredits],
    e.[AttendanceIntensity],
    e.[EntryStatus],
    e.[IsCensusIncluded]
FROM [compliance].[CensusSnapshot] AS s
INNER JOIN [compliance].[CensusRuleVersion] AS r
    ON s.[RuleVersion] = r.[RuleVersion]
   AND r.[IsCurrent] = 1
INNER JOIN [compliance].[CensusSnapshotEnrollment] AS e ON s.[CensusSnapshotId] = e.[CensusSnapshotId]
LEFT JOIN [security].[StudentPseudonym] AS sp ON e.[IdNumber] = sp.[IdNumber];
