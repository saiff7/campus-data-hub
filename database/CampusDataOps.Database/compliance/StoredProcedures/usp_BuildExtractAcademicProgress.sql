-- R4 Academic progress for one term.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractAcademicProgress]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, CONCAT(
        N'IdNumber,TermCode,ProgramCode,AttemptedCredits,EarnedCredits,GpaCredits,',
        N'QualityPoints,TermGpa,CumulativeAttemptedCredits,CumulativeEarnedCredits,',
        N'CumulativeGpaCredits,CumulativeGpa,AcademicStanding,GradesPending,',
        N'RequiredCredits,IsCompletionEligible,HasCredential'
    ));

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY a.[IdNumber]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[IdNumber])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), a.[TermCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), a.[ProgramCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[AttemptedCredits])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[EarnedCredits])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[GpaCredits])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[QualityPoints])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[TermGpa])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[CumulativeAttemptedCredits])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[CumulativeEarnedCredits])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[CumulativeGpaCredits])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[CumulativeGpa])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), a.[AcademicStanding])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[GradesPending])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[RequiredCredits])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[IsCompletionEligible])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), a.[HasCredential]))
        ) AS [LineText]
    FROM [reporting].[vw_AcademicProgress] AS a
    WHERE a.[TermCode] = @ReportingPeriod;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'ATTEMPTED_CREDITS', 'RECONCILIATION', '=',
            (
                SELECT ISNULL(SUM(e.[CreditHours]), 0) FROM [core].[vw_Enrollment] AS e
                WHERE e.[TermCode] = @ReportingPeriod AND e.[IsAttempted] = 1
            ),
            (
                SELECT ISNULL(SUM(a.[AttemptedCredits]), 0)
                FROM [reporting].[vw_AcademicProgress] AS a
                WHERE a.[TermCode] = @ReportingPeriod
            ),
            NULL
        ),
        (
            'EARNED_ABOVE_ATTEMPTED_ROWS', 'RULE', '=',
            0,
            (
                SELECT COUNT(*)
                FROM [reporting].[vw_AcademicProgress] AS a
                WHERE a.[TermCode] = @ReportingPeriod AND a.[EarnedCredits] > a.[AttemptedCredits]
            ),
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
