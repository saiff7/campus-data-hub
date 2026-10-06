-- R2 Financial aid packaging for one aid year.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractAidPackaging]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, CONCAT(
        N'IdNumber,AidYear,FundCode,FundSource,FundType,AwardCount,OfferedAmount,',
        N'AcceptedAmount,DisbursedAmount,CancelledAmount,DeclinedAmount,RemainingAmount'
    ));

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY p.[IdNumber], p.[FundCode]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), p.[IdNumber])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), p.[AidYear])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), p.[FundCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), p.[FundSource])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), p.[FundType])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), p.[AwardCount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), p.[OfferedAmount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), p.[AcceptedAmount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), p.[DisbursedAmount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), p.[CancelledAmount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), p.[DeclinedAmount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), p.[RemainingAmount]))
        ) AS [LineText]
    FROM [reporting].[vw_FinancialAidPackaging] AS p
    WHERE p.[AidYear] = @ReportingPeriod;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'OFFERED_TOTAL', 'RECONCILIATION', '=',
            (SELECT ISNULL(SUM(a.[OfferedAmount]), 0) FROM [core].[vw_AidAward] AS a WHERE a.[AidYear] = @ReportingPeriod),
            (
                SELECT ISNULL(SUM(p.[OfferedAmount]), 0)
                FROM [reporting].[vw_FinancialAidPackaging] AS p
                WHERE p.[AidYear] = @ReportingPeriod
            ),
            NULL
        ),
        (
            'ACCEPTED_TOTAL', 'RECONCILIATION', '=',
            (SELECT ISNULL(SUM(a.[AcceptedAmount]), 0) FROM [core].[vw_AidAward] AS a WHERE a.[AidYear] = @ReportingPeriod),
            (
                SELECT ISNULL(SUM(p.[AcceptedAmount]), 0)
                FROM [reporting].[vw_FinancialAidPackaging] AS p
                WHERE p.[AidYear] = @ReportingPeriod
            ),
            NULL
        ),
        (
            'DISBURSED_TOTAL', 'RECONCILIATION', '=',
            (SELECT ISNULL(SUM(a.[DisbursedAmount]), 0) FROM [core].[vw_AidAward] AS a WHERE a.[AidYear] = @ReportingPeriod),
            (
                SELECT ISNULL(SUM(p.[DisbursedAmount]), 0)
                FROM [reporting].[vw_FinancialAidPackaging] AS p
                WHERE p.[AidYear] = @ReportingPeriod
            ),
            NULL
        ),
        (
            'NEGATIVE_REMAINING_ROWS', 'RULE', '=',
            0,
            (
                SELECT COUNT(*)
                FROM [reporting].[vw_FinancialAidPackaging] AS p
                WHERE p.[AidYear] = @ReportingPeriod AND p.[RemainingAmount] < 0
            ),
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
