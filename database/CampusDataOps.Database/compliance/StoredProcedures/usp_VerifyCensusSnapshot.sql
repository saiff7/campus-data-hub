-- Recomputes a census snapshot's row checksum and compares it with the stored one. Returns one
-- row; raises 52011 on a mismatch unless @ThrowOnMismatch = 0.
CREATE PROCEDURE [compliance].[usp_VerifyCensusSnapshot]
    @CensusSnapshotId INT,
    @ThrowOnMismatch  BIT = 1,
    @IsValid          BIT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Rows [compliance].[CensusRowList];
    DECLARE @Stored BINARY (32);
    DECLARE @Recomputed BINARY (32);
    DECLARE @Message NVARCHAR (400);

    SET @Stored = (SELECT s.[RowChecksum] FROM [compliance].[CensusSnapshot] AS s WHERE s.[CensusSnapshotId] = @CensusSnapshotId);
    IF @Stored IS NULL
    BEGIN
        SET @Message = CONCAT(N'Census snapshot ', ISNULL(CONVERT(NVARCHAR (12), @CensusSnapshotId), N'NULL'), N' does not exist.');
        THROW 52012, @Message, 1;
    END;

    INSERT INTO @Rows (
        [IdNumber], [ProgramCode], [EntryTermCode], [StudentStatus], [ResidencyCode], [CensusCredits], [CountedSections],
        [AttendanceIntensity], [EntryStatus], [AgeAtCensus], [IsCensusIncluded], [ExclusionReason]
    )
    SELECT
        e.[IdNumber], e.[ProgramCode], e.[EntryTermCode], e.[StudentStatus], e.[ResidencyCode], e.[CensusCredits],
        e.[CountedSections], e.[AttendanceIntensity], e.[EntryStatus], e.[AgeAtCensus], e.[IsCensusIncluded],
        e.[ExclusionReason]
    FROM [compliance].[CensusSnapshotEnrollment] AS e
    WHERE e.[CensusSnapshotId] = @CensusSnapshotId;

    SET @Recomputed = [compliance].[fn_CensusRowsChecksum](@Rows);
    SET @IsValid = CONVERT(BIT, CASE WHEN @Recomputed = @Stored THEN 1 ELSE 0 END);

    SELECT
        @CensusSnapshotId AS [CensusSnapshotId],
        CONVERT(CHAR (64), @Stored, 2) AS [StoredChecksum],
        CONVERT(CHAR (64), @Recomputed, 2) AS [RecomputedChecksum],
        @IsValid AS [IsValid];

    IF @IsValid = 0 AND @ThrowOnMismatch = 1
    BEGIN
        SET @Message = CONCAT(N'Census snapshot ', @CensusSnapshotId, N' rows no longer match their checksum.');
        THROW 52011, @Message, 1;
    END;
END;
