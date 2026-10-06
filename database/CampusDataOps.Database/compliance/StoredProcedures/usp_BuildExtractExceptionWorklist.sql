-- R5 Masked exception worklist.
-- Writes the header (line 1), one line per data row in a fixed order, and the control totals
-- (docs/specifications/extract-controls.md). Called only by compliance.usp_GenerateExtract.
CREATE PROCEDURE [compliance].[usp_BuildExtractExceptionWorklist]
    @ExtractRunId     BIGINT,
    @ReportingPeriod  VARCHAR (20),
    @CensusSnapshotId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    VALUES (@ExtractRunId, 1, CONCAT(
        N'ExceptionId,ExceptionReasonCode,Severity,OwnerDepartment,ExceptionStatusCode,',
        N'AssignedTo,ApplicationId,DetailCode,CurrentDecisionType,CandidateCount,AgeDays,',
        N'ApplicantInitials,BirthYear,MaskedEmail,EntryTermCodeRaw,ProgramChoice1Raw,',
        N'PermittedNextStatuses'
    ));

    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText])
    SELECT
        @ExtractRunId AS [ExtractRunId],
        1 + ROW_NUMBER() OVER (ORDER BY w.[ExceptionId]) AS [LineNumber],
        CONCAT_WS(
            N',',
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), w.[ExceptionId])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[ExceptionReasonCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[Severity])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[OwnerDepartment])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[ExceptionStatusCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[AssignedTo])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[ApplicationId])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[DetailCode])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[CurrentDecisionType])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), w.[CandidateCount])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), w.[AgeDays])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[ApplicantInitials])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (40), w.[BirthYear])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[MaskedEmail])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[EntryTermCodeRaw])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[ProgramChoice1Raw])),
            [compliance].[fn_CsvField](CONVERT(NVARCHAR (4000), w.[PermittedNextStatuses]))
        ) AS [LineText]
    FROM [reporting].[vw_ExceptionWorklist] AS w;

    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]
    )
    SELECT
        @ExtractRunId AS [ExtractRunId], ctl.[ControlCode], ctl.[ControlKind], ctl.[ComparisonOperator], ctl.[ExpectedValue],
        ctl.[ActualValue], ctl.[Note]
    FROM (
        VALUES
        (
            'ACTIVE_EXCEPTIONS', 'RECONCILIATION', '=',
            (
                SELECT COUNT(*) FROM [integration].[IntegrationException] AS e
                INNER JOIN [reference].[ExceptionStatus] AS s ON e.[ExceptionStatusCode] = s.[ExceptionStatusCode]
                WHERE s.[IsActiveState] = 1
            ),
            (SELECT COUNT(w.[ExceptionId]) FROM [reporting].[vw_ExceptionWorklist] AS w),
            NULL
        )
    ) AS ctl ([ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue], [Note]);
END;
