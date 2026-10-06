-- R3 Student account aging as of one date.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractAccountAging]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AsOfDate DATE = CONVERT(DATE, @ReportingPeriod, 23);

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, CONCAT(
        N'IdNumber,AsOfDate,NetBalance,CurrentAmount,Days001To030,Days031To060,',
        N'Days061To090,Days091Plus,CreditBalance,TransactionCount,LastPaymentDate'
    ));

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY a.[IdNumber]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[IdNumber])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (10), a.[AsOfDate], 23)),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[NetBalance])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[CurrentAmount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[Days001To030])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[Days031To060])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[Days061To090])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[Days091Plus])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[CreditBalance])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[TransactionCount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (10), a.[LastPaymentDate], 23))
        ) AS [LineText]
    FROM [reporting].[fn_StudentAccountAging](@AsOfDate) AS a;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'NET_BALANCE_TOTAL', 'RECONCILIATION', '=',
            (SELECT ISNULL(SUM(t.[Amount]), 0) FROM [core].[vw_AccountTransaction] AS t WHERE t.[PostedDate] <= @AsOfDate),
            (SELECT ISNULL(SUM(a.[NetBalance]), 0) FROM [reporting].[fn_StudentAccountAging](@AsOfDate) AS a),
            NULL
        ),
        (
            'BUCKET_INVARIANT_BREAKS', 'RULE', '=',
            0,
            (
                SELECT COUNT(*) FROM [reporting].[fn_StudentAccountAging](@AsOfDate) AS a
                WHERE a.[CurrentAmount] + a.[Days001To030] + a.[Days031To060] + a.[Days061To090] + a.[Days091Plus]
                    - a.[CreditBalance] <> a.[NetBalance]
            ),
            NULL
        ),
        (
            'DAYS_091_PLUS_TOTAL', 'INFO', '=',
            NULL,
            (SELECT ISNULL(SUM(a.[Days091Plus]), 0) FROM [reporting].[fn_StudentAccountAging](@AsOfDate) AS a),
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
