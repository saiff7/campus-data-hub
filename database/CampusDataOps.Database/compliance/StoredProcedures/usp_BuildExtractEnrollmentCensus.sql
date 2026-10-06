-- R1 Enrollment census extract for one term, from its census snapshot.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractEnrollmentCensus]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Population INT;
    DECLARE @Included INT;
    DECLARE @Credits DECIMAL (9, 1);
    DECLARE @IsValid BIT;
    DECLARE @Message NVARCHAR (400);

    SELECT @CensusSnapshotId = s.[CensusSnapshotId], @Population = s.[PopulationCount], @Included = s.[IncludedCount],
        @Credits = s.[CreditTotal]
    FROM [compliance].[CensusSnapshot] AS s
    INNER JOIN [compliance].[CensusRuleVersion] AS r
        ON s.[RuleVersion] = r.[RuleVersion]
       AND r.[IsCurrent] = 1
    WHERE s.[TermCode] = @ReportingPeriod;

    IF @CensusSnapshotId IS NULL
    BEGIN
        SET @Message = CONCAT(N'Term ', @ReportingPeriod, N' has no census snapshot for the current rule version.');
        THROW 52130, @Message, 1;
    END;

    EXEC [compliance].[usp_VerifyCensusSnapshot]
        @CensusSnapshotId = @CensusSnapshotId, @ThrowOnMismatch = 0, @ReturnResult = 0, @IsValid = @IsValid OUTPUT;

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, CONCAT(
        N'CensusSnapshotId,TermCode,CensusDate,RuleVersion,IdNumber,ProgramCode,',
        N'CredentialLevel,EntryTermCode,ResidencyCode,CensusCredits,CountedSections,',
        N'AttendanceIntensity,EntryStatus,AgeAtCensus,IsCensusIncluded,ExclusionReason'
    ));

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY c.[IdNumber]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), c.[CensusSnapshotId])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[TermCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (10), c.[CensusDate], 23)),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[RuleVersion])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), c.[IdNumber])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[ProgramCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[CredentialLevel])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[EntryTermCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[ResidencyCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), c.[CensusCredits])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), c.[CountedSections])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[AttendanceIntensity])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[EntryStatus])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), c.[AgeAtCensus])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), c.[IsCensusIncluded])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), c.[ExclusionReason]))
        ) AS [LineText]
    FROM [reporting].[vw_EnrollmentCensus] AS c
    WHERE c.[CensusSnapshotId] = @CensusSnapshotId;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'ROW_COUNT', 'RECONCILIATION', '=',
            @Population,
            (SELECT COUNT(*) FROM [reporting].[vw_EnrollmentCensus] AS c WHERE c.[CensusSnapshotId] = @CensusSnapshotId),
            NULL
        ),
        (
            'INCLUDED_COUNT', 'RECONCILIATION', '=',
            @Included,
            (
                SELECT COUNT(*) FROM [reporting].[vw_EnrollmentCensus] AS c
                WHERE c.[CensusSnapshotId] = @CensusSnapshotId AND c.[IsCensusIncluded] = 1
            ),
            NULL
        ),
        (
            'CREDIT_TOTAL', 'RECONCILIATION', '=',
            @Credits,
            (
                SELECT ISNULL(SUM(c.[CensusCredits]), 0) FROM [reporting].[vw_EnrollmentCensus] AS c
                WHERE c.[CensusSnapshotId] = @CensusSnapshotId AND c.[IsCensusIncluded] = 1
            ),
            NULL
        ),
        (
            'SNAPSHOT_CHECKSUM_VALID', 'RULE', '=',
            1,
            @IsValid,
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
