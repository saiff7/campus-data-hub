-- Power BI term dimension, with whether the term has a census snapshot (current rule version).
CREATE VIEW [bi].[DimTerm]
AS
SELECT
    t.[TermCode],
    t.[TermName],
    t.[TermType],
    t.[AcademicYear],
    t.[StartDate],
    t.[CensusDate],
    t.[EndDate],
    CAST(CASE WHEN s.[CensusSnapshotId] IS NULL THEN 0 ELSE 1 END AS BIT) AS [HasCensusSnapshot],
    YEAR(t.[StartDate]) * 10 + CASE t.[TermType] WHEN 'SPRING' THEN 1 WHEN 'SUMMER' THEN 2 ELSE 3 END AS [TermSortKey]
FROM [reference].[AcademicTerm] AS t
LEFT JOIN [compliance].[CensusSnapshot] AS s
    ON t.[TermCode] = s.[TermCode]
   AND s.[RuleVersion] = (SELECT r.[RuleVersion] FROM [compliance].[CensusRuleVersion] AS r WHERE r.[IsCurrent] = 1);
