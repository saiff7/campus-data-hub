-- EDUCATIONAL SIMULATION of the IPEDS Student Financial Aid component; not an IPEDS submission
-- (docs/specifications/ipeds-measure-mapping.md). Group 1: the 12-month population of the aid
-- year. Group 2: full-time ENTERING students included in that year's fall census snapshot.
-- Aid counted: ACCEPTED awards, at their accepted amount.
CREATE VIEW [compliance].[vw_IPEDS_StudentFinancialAid]
AS
WITH [GroupMember] AS (
    SELECT m.[AcademicYear], 'GROUP_1' AS [StudentGroup], m.[IdNumber]
    FROM [compliance].[vw_TwelveMonthStudent] AS m
    UNION ALL
    SELECT t.[AcademicYear], 'GROUP_2' AS [StudentGroup], e.[IdNumber]
    FROM [compliance].[CensusSnapshot] AS s
    INNER JOIN [compliance].[CensusRuleVersion] AS r
        ON s.[RuleVersion] = r.[RuleVersion]
       AND r.[IsCurrent] = 1
    INNER JOIN [reference].[AcademicTerm] AS t
        ON s.[TermCode] = t.[TermCode]
       AND t.[TermType] = 'FALL'
    INNER JOIN [compliance].[CensusSnapshotEnrollment] AS e ON s.[CensusSnapshotId] = e.[CensusSnapshotId]
    WHERE e.[IsCensusIncluded] = 1
      AND e.[AttendanceIntensity] = 'FULL_TIME'
      AND e.[EntryStatus] = 'ENTERING'
),

[StudentAid] AS (
    SELECT
        a.[AidYear],
        a.[IdNumber],
        SUM(a.[AcceptedAmount]) AS [AnyAid],
        SUM(CASE WHEN a.[FundType] = 'GRANT' THEN a.[AcceptedAmount] ELSE 0 END) AS [AnyGrant],
        SUM(CASE WHEN a.[IsPell] = 1 THEN a.[AcceptedAmount] ELSE 0 END) AS [Pell],
        SUM(CASE WHEN a.[IsFederalStudentLoan] = 1 THEN a.[AcceptedAmount] ELSE 0 END) AS [FederalStudentLoan]
    FROM [core].[vw_AidAward] AS a
    WHERE a.[AwardStatus] = 'ACCEPTED'
    GROUP BY a.[AidYear], a.[IdNumber]
),

[MemberAid] AS (
    SELECT g.[AcademicYear], g.[StudentGroup], g.[IdNumber], x.[AidType], x.[Amount]
    FROM [GroupMember] AS g
    LEFT JOIN [StudentAid] AS sa
        ON g.[AcademicYear] = sa.[AidYear]
       AND g.[IdNumber] = sa.[IdNumber]
    CROSS APPLY (
        VALUES
            ('COHORT', CAST(0 AS DECIMAL (12, 2))),
            ('ANY_AID', ISNULL(sa.[AnyAid], 0)),
            ('ANY_GRANT', ISNULL(sa.[AnyGrant], 0)),
            ('PELL', ISNULL(sa.[Pell], 0)),
            ('FEDERAL_STUDENT_LOAN', ISNULL(sa.[FederalStudentLoan], 0))
    ) AS x ([AidType], [Amount])
)

SELECT
    ma.[AcademicYear] AS [ReportingPeriod],
    ma.[StudentGroup],
    ma.[AidType],
    CAST(SUM(CASE WHEN ma.[AidType] = 'COHORT' OR ma.[Amount] > 0 THEN 1 ELSE 0 END) AS INT) AS [RecipientCount],
    CAST(SUM(ma.[Amount]) AS DECIMAL (14, 2)) AS [TotalAmount],
    CAST(ROUND(SUM(ma.[Amount]) / NULLIF(SUM(CASE WHEN ma.[AidType] <> 'COHORT' AND ma.[Amount] > 0 THEN 1 ELSE 0 END), 0), 0)
        AS DECIMAL (14, 0)) AS [AverageAmount]
FROM [MemberAid] AS ma
GROUP BY ma.[AcademicYear], ma.[StudentGroup], ma.[AidType];
