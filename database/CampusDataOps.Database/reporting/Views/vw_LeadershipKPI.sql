-- R6 Leadership KPI dataset (docs/specifications/report-catalog.md). Grain: one row per term and
-- measure; definitions, owners and lineage are in compliance.MeasureDefinition. Census measures
-- come only from snapshots (DataStatus FINAL, or NO_SNAPSHOT with a NULL value); the rest are
-- computed from current data (DataStatus CURRENT).
CREATE VIEW [reporting].[vw_LeadershipKPI]
AS
WITH [Today] AS (
    SELECT CAST(SYSUTCDATETIME() AS DATE) AS [AsOfDate]
),

[Funnel] AS (
    SELECT
        a.[FunnelTermCode] AS [TermCode],
        SUM(CASE WHEN a.[ApplicationStatus] <> 'STARTED' THEN 1 ELSE 0 END) AS [Applications],
        SUM(CASE WHEN a.[ApplicationStatus] = 'ADMITTED' OR a.[ApplicationStatus] = 'DEPOSITED' THEN 1 ELSE 0 END) AS [Admits],
        SUM(CASE WHEN a.[ApplicationStatus] = 'DEPOSITED' THEN 1 ELSE 0 END) AS [Deposits]
    FROM [core].[vw_Application] AS a
    WHERE a.[FunnelTermCode] IS NOT NULL
    GROUP BY a.[FunnelTermCode]
),

[Census] AS (
    SELECT s.[TermCode], s.[IncludedCount], s.[FullTimeCount], s.[CreditTotal]
    FROM [compliance].[CensusSnapshot] AS s
    INNER JOIN [compliance].[CensusRuleVersion] AS r
        ON s.[RuleVersion] = r.[RuleVersion]
       AND r.[IsCurrent] = 1
),

[Aid] AS (
    SELECT a.[TermCode], COUNT(DISTINCT a.[IdNumber]) AS [Recipients]
    FROM [core].[vw_AidAward] AS a
    WHERE a.[AwardStatus] = 'ACCEPTED'
    GROUP BY a.[TermCode]
),

[Success] AS (
    SELECT
        e.[TermCode],
        SUM(CASE WHEN e.[IsAttempted] = 1 AND e.[GradeCode] IS NOT NULL THEN 1 ELSE 0 END) AS [GradedSections],
        SUM(CASE WHEN e.[IsAttempted] = 1 AND e.[GradePoints] >= 2.00 THEN 1 ELSE 0 END) AS [SuccessfulSections]
    FROM [core].[vw_Enrollment] AS e
    GROUP BY e.[TermCode]
),

[Completion] AS (
    SELECT c.[TermCode], COUNT(*) AS [Credentials]
    FROM [core].[vw_Credential] AS c
    GROUP BY c.[TermCode]
),

[Balance] AS (
    SELECT t.[TermCode], SUM(CASE WHEN ag.[NetBalance] > 0 THEN ag.[NetBalance] ELSE 0 END) AS [OutstandingBalance]
    FROM [reference].[AcademicTerm] AS t
    CROSS JOIN [Today] AS td
    CROSS APPLY [reporting].[fn_StudentAccountAging](
        CASE WHEN t.[EndDate] < td.[AsOfDate] THEN t.[EndDate] ELSE td.[AsOfDate] END
    ) AS ag
    WHERE t.[StartDate] <= td.[AsOfDate]
    GROUP BY t.[TermCode]
)

SELECT
    t.[TermCode],
    t.[AcademicYear],
    t.[TermType],
    md.[MeasureCode],
    md.[MeasureName],
    md.[Unit],
    md.[OwnerDepartmentCode],
    m.[MeasureValue],
    m.[DataStatus]
FROM [reference].[AcademicTerm] AS t
LEFT JOIN [Funnel] AS f ON t.[TermCode] = f.[TermCode]
LEFT JOIN [Census] AS c ON t.[TermCode] = c.[TermCode]
LEFT JOIN [Aid] AS a ON t.[TermCode] = a.[TermCode]
LEFT JOIN [Success] AS s ON t.[TermCode] = s.[TermCode]
LEFT JOIN [Completion] AS cp ON t.[TermCode] = cp.[TermCode]
LEFT JOIN [Balance] AS b ON t.[TermCode] = b.[TermCode]
CROSS APPLY (
    VALUES
        ('APPLICATIONS', CAST(ISNULL(f.[Applications], 0) AS DECIMAL (18, 4)), 'CURRENT'),
        ('ADMITS', CAST(ISNULL(f.[Admits], 0) AS DECIMAL (18, 4)), 'CURRENT'),
        ('DEPOSITS', CAST(ISNULL(f.[Deposits], 0) AS DECIMAL (18, 4)), 'CURRENT'),
        ('YIELD_RATE', CAST(CAST(f.[Deposits] AS DECIMAL (18, 4)) / NULLIF(f.[Admits], 0) AS DECIMAL (18, 4)), 'CURRENT'),
        (
            'CENSUS_HEADCOUNT',
            CAST(c.[IncludedCount] AS DECIMAL (18, 4)),
            CASE WHEN c.[TermCode] IS NULL THEN 'NO_SNAPSHOT' ELSE 'FINAL' END
        ),
        (
            'CENSUS_FTE',
            CAST(c.[CreditTotal] / 15.0 AS DECIMAL (18, 4)),
            CASE WHEN c.[TermCode] IS NULL THEN 'NO_SNAPSHOT' ELSE 'FINAL' END
        ),
        (
            'FULL_TIME_SHARE',
            CAST(CAST(c.[FullTimeCount] AS DECIMAL (18, 4)) / NULLIF(c.[IncludedCount], 0) AS DECIMAL (18, 4)),
            CASE WHEN c.[TermCode] IS NULL THEN 'NO_SNAPSHOT' ELSE 'FINAL' END
        ),
        ('AID_RECIPIENTS', CAST(ISNULL(a.[Recipients], 0) AS DECIMAL (18, 4)), 'CURRENT'),
        ('OUTSTANDING_BALANCE', CAST(b.[OutstandingBalance] AS DECIMAL (18, 4)), 'CURRENT'),
        (
            'COURSE_SUCCESS_RATE',
            CAST(CAST(s.[SuccessfulSections] AS DECIMAL (18, 4)) / NULLIF(s.[GradedSections], 0) AS DECIMAL (18, 4)),
            'CURRENT'
        ),
        ('COMPLETIONS', CAST(ISNULL(cp.[Credentials], 0) AS DECIMAL (18, 4)), 'CURRENT')
) AS m ([MeasureCode], [MeasureValue], [DataStatus])
INNER JOIN [compliance].[MeasureDefinition] AS md ON m.[MeasureCode] = md.[MeasureCode];
