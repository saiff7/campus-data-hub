-- One row per person and term with any enrollment: the census population before rule-version
-- thresholds are applied (docs/specifications/report-catalog.md R1). compliance.usp_CaptureCensusSnapshot
-- applies the current rule version and freezes the result.
-- EntryStatus is ENTERING when the entry term is this term, or this is a fall term and the entry
-- term is the summer of the same calendar year; IPEDS counts prior-summer starters as first-time
-- in fall. AgeAtCensus is whole years on the census date.
CREATE VIEW [core].[vw_StudentTermCensus]
AS
WITH [TermEnrollment] AS (
    SELECT
        e.[IdNumber],
        e.[TermCode],
        SUM(CASE WHEN e.[IsCountedAtCensus] = 1 THEN e.[CreditHours] ELSE 0 END) AS [CensusCredits],
        SUM(CASE WHEN e.[IsCountedAtCensus] = 1 THEN 1 ELSE 0 END) AS [CountedSections],
        SUM(CASE WHEN e.[IsRegisteredByCensus] = 1 THEN 1 ELSE 0 END) AS [SectionsRegisteredByCensus]
    FROM [core].[vw_Enrollment] AS e
    GROUP BY e.[IdNumber], e.[TermCode]
)

SELECT
    te.[IdNumber],
    te.[TermCode],
    t.[TermType],
    t.[CensusDate],
    CAST(CASE WHEN s.[IdNumber] IS NULL THEN 0 ELSE 1 END AS BIT) AS [HasStudentRecord],
    s.[ProgramCode],
    s.[EntryTermCode],
    s.[StudentStatus],
    s.[ResidencyCode],
    CAST(te.[CensusCredits] AS DECIMAL (5, 1)) AS [CensusCredits],
    te.[CountedSections],
    te.[SectionsRegisteredByCensus],
    CASE
        WHEN s.[IdNumber] IS NULL THEN NULL
        WHEN s.[EntryTermCode] = te.[TermCode] THEN 'ENTERING'
        WHEN t.[TermType] = 'FALL' AND et.[TermType] = 'SUMMER' AND YEAR(et.[StartDate]) = YEAR(t.[StartDate]) THEN 'ENTERING'
        ELSE 'CONTINUING'
    END AS [EntryStatus],
    CASE
        WHEN s.[BirthDate] IS NULL THEN NULL
        ELSE DATEDIFF(YEAR, s.[BirthDate], t.[CensusDate])
            - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, s.[BirthDate], t.[CensusDate]), s.[BirthDate]) > t.[CensusDate] THEN 1 ELSE 0 END
    END AS [AgeAtCensus]
FROM [TermEnrollment] AS te
INNER JOIN [reference].[AcademicTerm] AS t ON te.[TermCode] = t.[TermCode]
LEFT JOIN [core].[vw_Student] AS s ON te.[IdNumber] = s.[IdNumber]
LEFT JOIN [reference].[AcademicTerm] AS et ON s.[EntryTermCode] = et.[TermCode];
