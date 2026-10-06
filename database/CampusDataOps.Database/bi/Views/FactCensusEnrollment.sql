-- Census enrollment facts from snapshots (current rule version). Grain: student and term.
CREATE VIEW [bi].[FactCensusEnrollment]
AS
SELECT
    s.[CensusSnapshotId],
    s.[TermCode],
    sp.[StudentKey],
    e.[ProgramCode],
    e.[CensusCredits],
    e.[AttendanceIntensity],
    e.[EntryStatus],
    e.[ResidencyCode],
    e.[IsCensusIncluded],
    e.[ExclusionReason]
FROM [compliance].[CensusSnapshot] AS s
INNER JOIN [compliance].[CensusRuleVersion] AS r
    ON s.[RuleVersion] = r.[RuleVersion]
   AND r.[IsCurrent] = 1
INNER JOIN [compliance].[CensusSnapshotEnrollment] AS e ON s.[CensusSnapshotId] = e.[CensusSnapshotId]
LEFT JOIN [security].[StudentPseudonym] AS sp ON e.[IdNumber] = sp.[IdNumber];
