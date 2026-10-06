-- EDUCATIONAL SIMULATION of the IPEDS Completions component; not an IPEDS submission
-- (docs/specifications/ipeds-measure-mapping.md). Awards dated 1 July to 30 June by 6-digit CIP
-- code and award level, and unduplicated completers by level and in total.
CREATE VIEW [compliance].[vw_IPEDS_Completions]
AS
SELECT
    c.[ReportingYear] AS [ReportingPeriod],
    'AWARDS' AS [Section],
    c.[CipCode],
    c.[IpedsAwardLevel] AS [AwardLevel],
    COUNT(*) AS [AwardCount]
FROM [core].[vw_Credential] AS c
GROUP BY c.[ReportingYear], c.[CipCode], c.[IpedsAwardLevel]
UNION ALL
SELECT
    c.[ReportingYear] AS [ReportingPeriod],
    'COMPLETERS_BY_LEVEL' AS [Section],
    'ALL' AS [CipCode],
    c.[IpedsAwardLevel] AS [AwardLevel],
    COUNT(DISTINCT c.[IdNumber]) AS [AwardCount]
FROM [core].[vw_Credential] AS c
GROUP BY c.[ReportingYear], c.[IpedsAwardLevel]
UNION ALL
SELECT
    c.[ReportingYear] AS [ReportingPeriod],
    'COMPLETERS_TOTAL' AS [Section],
    'ALL' AS [CipCode],
    'ALL' AS [AwardLevel],
    COUNT(DISTINCT c.[IdNumber]) AS [AwardCount]
FROM [core].[vw_Credential] AS c
GROUP BY c.[ReportingYear];
