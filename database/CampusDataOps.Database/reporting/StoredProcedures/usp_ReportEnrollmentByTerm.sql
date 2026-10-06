-- R1 for one term. Raises 52201 when the term has no snapshot under the current rule version
-- rather than reporting live data.
CREATE PROCEDURE [reporting].[usp_ReportEnrollmentByTerm]
    @TermCode        VARCHAR (10),
    @IncludeExcluded BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Message NVARCHAR (400);

    IF NOT EXISTS (SELECT 1 FROM [reporting].[vw_EnrollmentCensus] AS c WHERE c.[TermCode] = @TermCode)
    BEGIN
        SET @Message = CONCAT(
            N'Term ', ISNULL(@TermCode, N'NULL'),
            N' has no census snapshot for the current rule version; capture one after its census date.'
        );
        THROW 52201, @Message, 1;
    END;

    SELECT
        c.[CensusSnapshotId], c.[TermCode], c.[CensusDate], c.[RuleVersion], c.[IdNumber], c.[ProgramCode], c.[ProgramName],
        c.[CredentialLevel], c.[EntryTermCode], c.[ResidencyCode], c.[CensusCredits], c.[CountedSections],
        c.[AttendanceIntensity], c.[EntryStatus], c.[AgeAtCensus], c.[IsCensusIncluded], c.[ExclusionReason]
    FROM [reporting].[vw_EnrollmentCensus] AS c
    WHERE c.[TermCode] = @TermCode
      AND (@IncludeExcluded = 1 OR c.[IsCensusIncluded] = 1)
    ORDER BY c.[IdNumber];
END;
