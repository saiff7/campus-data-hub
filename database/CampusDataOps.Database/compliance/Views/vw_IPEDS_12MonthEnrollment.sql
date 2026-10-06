-- EDUCATIONAL SIMULATION of the IPEDS 12-month Enrollment component; not an IPEDS submission
-- (docs/specifications/ipeds-measure-mapping.md). Unduplicated headcount and attempted credit
-- hours per academic year (1 July to 30 June). Sections: BY_STATUS and TOTAL.
CREATE VIEW [compliance].[vw_IPEDS_12MonthEnrollment]
AS
SELECT
    m.[AcademicYear] AS [ReportingPeriod],
    'BY_STATUS' AS [Section],
    m.[AttendanceStatus],
    m.[StudentCategory],
    COUNT(*) AS [Headcount],
    CAST(SUM(m.[CreditHours]) AS DECIMAL (9, 1)) AS [CreditHours]
FROM [compliance].[vw_TwelveMonthStudent] AS m
GROUP BY m.[AcademicYear], m.[AttendanceStatus], m.[StudentCategory]
UNION ALL
SELECT
    m.[AcademicYear] AS [ReportingPeriod],
    'TOTAL' AS [Section],
    'ALL' AS [AttendanceStatus],
    'ALL' AS [StudentCategory],
    COUNT(*) AS [Headcount],
    CAST(SUM(m.[CreditHours]) AS DECIMAL (9, 1)) AS [CreditHours]
FROM [compliance].[vw_TwelveMonthStudent] AS m
GROUP BY m.[AcademicYear];
