-- SHA-256 of census rows serialized as JSON in IdNumber order, with NULLs kept explicit. An empty
-- set hashes as the empty JSON array.
CREATE FUNCTION [compliance].[fn_CensusRowsChecksum] (@Rows [compliance].[CensusRowList] READONLY)
RETURNS BINARY (32)
AS
BEGIN
    RETURN HASHBYTES('SHA2_256', ISNULL((
        SELECT
            r.[IdNumber], r.[ProgramCode], r.[EntryTermCode], r.[StudentStatus], r.[ResidencyCode], r.[CensusCredits],
            r.[CountedSections], r.[AttendanceIntensity], r.[EntryStatus], r.[AgeAtCensus], r.[IsCensusIncluded],
            r.[ExclusionReason]
        FROM @Rows AS r
        ORDER BY r.[IdNumber]
        FOR JSON PATH, INCLUDE_NULL_VALUES
    ), N'[]'));
END;
