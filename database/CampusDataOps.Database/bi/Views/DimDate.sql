-- Power BI date dimension, 1 July 2024 to 30 June 2028 (the synthetic calendar's academic years).
-- AcademicYear is the July-June year; TermCode is the term whose dates contain the day, if any.
CREATE VIEW [bi].[DimDate]
AS
WITH [Day] AS (
    SELECT TOP (1461) DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY c.[object_id], c.[column_id]) - 1, CAST('2024-07-01' AS DATE)) AS [Date]
    FROM sys.all_columns AS c
)

SELECT
    d.[Date],
    t.[TermCode],
    YEAR(d.[Date]) * 10000 + MONTH(d.[Date]) * 100 + DAY(d.[Date]) AS [DateKey],
    YEAR(d.[Date]) AS [CalendarYear],
    MONTH(d.[Date]) AS [MonthNumber],
    DATENAME(MONTH, d.[Date]) AS [MonthName],
    CONCAT(
        YEAR(d.[Date]) - CASE WHEN MONTH(d.[Date]) < 7 THEN 1 ELSE 0 END, '-',
        YEAR(d.[Date]) + CASE WHEN MONTH(d.[Date]) < 7 THEN 0 ELSE 1 END
    ) AS [AcademicYear]
FROM [Day] AS d
LEFT JOIN [reference].[AcademicTerm] AS t ON d.[Date] BETWEEN t.[StartDate] AND t.[EndDate];
