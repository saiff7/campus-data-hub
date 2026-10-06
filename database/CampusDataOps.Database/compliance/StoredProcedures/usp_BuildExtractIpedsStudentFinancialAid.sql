-- IPEDS-aligned Student Financial Aid (educational simulation) for one aid year.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractIpedsStudentFinancialAid]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, N'ReportingPeriod,StudentGroup,AidType,RecipientCount,TotalAmount,AverageAmount');

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY a.[StudentGroup], a.[AidType]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), a.[ReportingPeriod])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), a.[StudentGroup])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), a.[AidType])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[RecipientCount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[TotalAmount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[AverageAmount]))
        ) AS [LineText]
    FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
    WHERE a.[ReportingPeriod] = @ReportingPeriod;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'GROUP_1_COHORT', 'INFO', '=',
            NULL,
            (
                SELECT ISNULL(SUM(a.[RecipientCount]), 0)
                FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
                WHERE a.[ReportingPeriod] = @ReportingPeriod AND a.[StudentGroup] = 'GROUP_1' AND a.[AidType] = 'COHORT'
            ),
            NULL
        ),
        (
            'GROUP_2_AT_MOST_GROUP_1', 'RULE', '<=',
            (
                SELECT ISNULL(SUM(a.[RecipientCount]), 0)
                FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
                WHERE a.[ReportingPeriod] = @ReportingPeriod AND a.[StudentGroup] = 'GROUP_1' AND a.[AidType] = 'COHORT'
            ),
            (
                SELECT ISNULL(SUM(a.[RecipientCount]), 0)
                FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
                WHERE a.[ReportingPeriod] = @ReportingPeriod AND a.[StudentGroup] = 'GROUP_2' AND a.[AidType] = 'COHORT'
            ),
            NULL
        ),
        (
            'GROUP_1_AID_AT_MOST_COHORT', 'RULE', '<=',
            (
                SELECT ISNULL(SUM(a.[RecipientCount]), 0)
                FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
                WHERE a.[ReportingPeriod] = @ReportingPeriod AND a.[StudentGroup] = 'GROUP_1' AND a.[AidType] = 'COHORT'
            ),
            (
                SELECT ISNULL(SUM(a.[RecipientCount]), 0)
                FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
                WHERE a.[ReportingPeriod] = @ReportingPeriod AND a.[StudentGroup] = 'GROUP_1' AND a.[AidType] = 'ANY_AID'
            ),
            NULL
        ),
        (
            'GROUP_2_AID_AT_MOST_COHORT', 'RULE', '<=',
            (
                SELECT ISNULL(SUM(a.[RecipientCount]), 0)
                FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
                WHERE a.[ReportingPeriod] = @ReportingPeriod AND a.[StudentGroup] = 'GROUP_2' AND a.[AidType] = 'COHORT'
            ),
            (
                SELECT ISNULL(SUM(a.[RecipientCount]), 0)
                FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
                WHERE a.[ReportingPeriod] = @ReportingPeriod AND a.[StudentGroup] = 'GROUP_2' AND a.[AidType] = 'ANY_AID'
            ),
            NULL
        ),
        (
            'GROUP_1_PELL_TOTAL', 'RECONCILIATION', '=',
            (
                SELECT ISNULL(SUM(aw.[AcceptedAmount]), 0)
                FROM [core].[vw_AidAward] AS aw
                WHERE aw.[AidYear] = @ReportingPeriod AND aw.[AwardStatus] = 'ACCEPTED' AND aw.[FundCode] = 'PELL'
                  AND aw.[IdNumber] IN (
                      SELECT e.[IdNumber] FROM [core].[vw_Enrollment] AS e
                      INNER JOIN [core].[vw_Term] AS t ON e.[TermCode] = t.[TermCode]
                      WHERE t.[AcademicYear] = @ReportingPeriod AND e.[IsAttempted] = 1
                  )
            ),
            (
                SELECT ISNULL(SUM(a.[TotalAmount]), 0)
                FROM [compliance].[vw_IPEDS_StudentFinancialAid] AS a
                WHERE a.[ReportingPeriod] = @ReportingPeriod AND a.[StudentGroup] = 'GROUP_1' AND a.[AidType] = 'PELL'
            ),
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
