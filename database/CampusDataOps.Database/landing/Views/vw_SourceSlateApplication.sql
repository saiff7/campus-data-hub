-- Extract boundary for Slate-Sim applications: one row per application with its ranked
-- program choices and its admitted-applicant export, if any.
CREATE VIEW [landing].[vw_SourceSlateApplication]
AS
SELECT
    a.[ApplicationId],
    a.[PersonId],
    a.[EntryTermCode],
    a.[StudentType],
    a.[CurrentStatus] AS [ApplicationStatus],
    a.[SubmittedAtUtc],
    a.[DecisionAtUtc],
    p1.[ProgramCode] AS [ProgramChoice1],
    p2.[ProgramCode] AS [ProgramChoice2],
    p3.[ProgramCode] AS [ProgramChoice3],
    eq.[QueuedAtUtc] AS [ExportQueuedAtUtc],
    GREATEST(a.[UpdatedAtUtc], p1.[UpdatedAtUtc], p2.[UpdatedAtUtc], p3.[UpdatedAtUtc], eq.[UpdatedAtUtc])
        AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[SlateSim].[Application] AS a
LEFT JOIN [$(SourceSystems)].[SlateSim].[ApplicationProgram] AS p1
    ON a.[ApplicationId] = p1.[ApplicationId]
   AND p1.[ChoiceRank] = 1
LEFT JOIN [$(SourceSystems)].[SlateSim].[ApplicationProgram] AS p2
    ON a.[ApplicationId] = p2.[ApplicationId]
   AND p2.[ChoiceRank] = 2
LEFT JOIN [$(SourceSystems)].[SlateSim].[ApplicationProgram] AS p3
    ON a.[ApplicationId] = p3.[ApplicationId]
   AND p3.[ChoiceRank] = 3
LEFT JOIN [$(SourceSystems)].[SlateSim].[ExportQueue] AS eq
    ON a.[ApplicationId] = eq.[ApplicationId]
   AND eq.[ExportType] = 'ADMITTED_APPLICANT';
