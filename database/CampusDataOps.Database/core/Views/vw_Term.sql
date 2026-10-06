-- Conformed academic terms. AcademicYearStartDate is 1 July of the academic year's first
-- calendar year, which is also the start of the IPEDS July-June reporting period.
CREATE VIEW [core].[vw_Term]
AS
SELECT
    t.[TermCode],
    t.[TermName],
    t.[TermType],
    t.[AcademicYear],
    t.[StartDate],
    t.[CensusDate],
    t.[EndDate],
    t.[IsOpenForAdmission],
    DATEFROMPARTS(CAST(LEFT(t.[AcademicYear], 4) AS INT), 7, 1) AS [AcademicYearStartDate]
FROM [reference].[AcademicTerm] AS t;
