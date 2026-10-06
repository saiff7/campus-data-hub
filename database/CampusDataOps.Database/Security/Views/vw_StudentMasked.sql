-- Masked student dimension for leadership, IR and Power BI (docs/architecture/security-model.md):
-- a random surrogate key and attributes only; no SIS ID, name, birth date or contact value.
-- AgeBand is the student's age band today, in the IPEDS Fall Enrollment bands.
CREATE VIEW [security].[vw_StudentMasked]
AS
SELECT
    sp.[StudentKey],
    sp.[MaskedStudentId],
    s.[ProgramCode],
    s.[EntryTermCode],
    s.[StudentStatus],
    s.[ResidencyCode],
    CASE
        WHEN a.[Age] IS NULL THEN 'UNKNOWN'
        WHEN a.[Age] < 18 THEN 'UNDER_18'
        WHEN a.[Age] <= 19 THEN '18-19'
        WHEN a.[Age] <= 21 THEN '20-21'
        WHEN a.[Age] <= 24 THEN '22-24'
        WHEN a.[Age] <= 29 THEN '25-29'
        WHEN a.[Age] <= 34 THEN '30-34'
        WHEN a.[Age] <= 39 THEN '35-39'
        WHEN a.[Age] <= 49 THEN '40-49'
        WHEN a.[Age] <= 64 THEN '50-64'
        ELSE '65_AND_OVER'
    END AS [AgeBand]
FROM [core].[vw_Student] AS s
INNER JOIN [security].[StudentPseudonym] AS sp ON s.[IdNumber] = sp.[IdNumber]
CROSS APPLY ( -- noqa: ST05
    SELECT DATEDIFF(YEAR, s.[BirthDate], d.[Today])
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, s.[BirthDate], d.[Today]), s.[BirthDate]) > d.[Today] THEN 1 ELSE 0 END AS [Age]
    FROM (SELECT CAST(SYSUTCDATETIME() AS DATE) AS [Today]) AS d
) AS a;
