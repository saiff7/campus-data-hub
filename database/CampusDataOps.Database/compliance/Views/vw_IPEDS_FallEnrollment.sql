-- EDUCATIONAL SIMULATION of the IPEDS Fall Enrollment component; not an IPEDS submission
-- (docs/specifications/ipeds-measure-mapping.md). Aggregates included students of each fall
-- term's census snapshot under the current rule version. Cells with no students are omitted.
-- Sections: PART_A (attendance x category x residency group), PART_B (attendance x age band), TOTAL.
CREATE VIEW [compliance].[vw_IPEDS_FallEnrollment]
AS
WITH [Included] AS (
    SELECT
        s.[TermCode],
        e.[AttendanceIntensity],
        e.[EntryStatus],
        CASE WHEN e.[ResidencyCode] = 'INTERNATIONAL' THEN 'INTERNATIONAL' ELSE 'DOMESTIC' END AS [ResidencyGroup],
        CASE
            WHEN e.[AgeAtCensus] IS NULL THEN 'UNKNOWN'
            WHEN e.[AgeAtCensus] < 18 THEN 'UNDER_18'
            WHEN e.[AgeAtCensus] <= 19 THEN '18-19'
            WHEN e.[AgeAtCensus] <= 21 THEN '20-21'
            WHEN e.[AgeAtCensus] <= 24 THEN '22-24'
            WHEN e.[AgeAtCensus] <= 29 THEN '25-29'
            WHEN e.[AgeAtCensus] <= 34 THEN '30-34'
            WHEN e.[AgeAtCensus] <= 39 THEN '35-39'
            WHEN e.[AgeAtCensus] <= 49 THEN '40-49'
            WHEN e.[AgeAtCensus] <= 64 THEN '50-64'
            ELSE '65_AND_OVER'
        END AS [AgeBand]
    FROM [compliance].[CensusSnapshot] AS s
    INNER JOIN [compliance].[CensusRuleVersion] AS r
        ON s.[RuleVersion] = r.[RuleVersion]
       AND r.[IsCurrent] = 1
    INNER JOIN [reference].[AcademicTerm] AS t
        ON s.[TermCode] = t.[TermCode]
       AND t.[TermType] = 'FALL'
    INNER JOIN [compliance].[CensusSnapshotEnrollment] AS e ON s.[CensusSnapshotId] = e.[CensusSnapshotId]
    WHERE e.[IsCensusIncluded] = 1
)

SELECT
    i.[TermCode] AS [ReportingPeriod],
    'PART_A' AS [Section],
    i.[AttendanceIntensity] AS [AttendanceStatus],
    i.[EntryStatus] AS [StudentCategory],
    i.[ResidencyGroup],
    'ALL' AS [AgeBand],
    COUNT(*) AS [Headcount]
FROM [Included] AS i
GROUP BY i.[TermCode], i.[AttendanceIntensity], i.[EntryStatus], i.[ResidencyGroup]
UNION ALL
SELECT
    i.[TermCode] AS [ReportingPeriod],
    'PART_B' AS [Section],
    i.[AttendanceIntensity] AS [AttendanceStatus],
    'ALL' AS [StudentCategory],
    'ALL' AS [ResidencyGroup],
    i.[AgeBand],
    COUNT(*) AS [Headcount]
FROM [Included] AS i
GROUP BY i.[TermCode], i.[AttendanceIntensity], i.[AgeBand]
UNION ALL
SELECT
    i.[TermCode] AS [ReportingPeriod],
    'TOTAL' AS [Section],
    'ALL' AS [AttendanceStatus],
    'ALL' AS [StudentCategory],
    'ALL' AS [ResidencyGroup],
    'ALL' AS [AgeBand],
    COUNT(*) AS [Headcount]
FROM [Included] AS i
GROUP BY i.[TermCode];
