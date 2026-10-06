-- Applicant funnel counts. Grain: entry term, program, application status and student type
-- (aggregate; no applicant identity).
CREATE VIEW [bi].[FactApplicationFunnel]
AS
SELECT
    a.[FunnelTermCode] AS [TermCode],
    a.[J1ProgramCode] AS [ProgramCode],
    a.[ApplicationStatus],
    a.[StudentType],
    COUNT(*) AS [ApplicationCount]
FROM [core].[vw_Application] AS a
WHERE a.[FunnelTermCode] IS NOT NULL
GROUP BY a.[FunnelTermCode], a.[J1ProgramCode], a.[ApplicationStatus], a.[StudentType];
