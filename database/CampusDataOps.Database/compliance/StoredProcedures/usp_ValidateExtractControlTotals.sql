-- Sets the prior-period comparison and outcome of every control total of a GENERATING run, and
-- the run's validation status (docs/specifications/extract-controls.md):
--   FAIL  a reconciliation, subtotal or rule control whose comparison is false;
--   WARN  such a control without an expected value (it could not be checked), or a change
--         against the latest earlier successful run (for term periods, of the same term type)
--         above the compliance.ControlThreshold limit;
--   PASS  otherwise. Failures and warnings are stored, never overwritten or hidden.
CREATE PROCEDURE [compliance].[usp_ValidateExtractControlTotals]
    @ExtractRunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE c
    SET c.[PriorExtractRunId] = pr.[ExtractRunId],
        c.[PriorValue] = pc.[ActualValue],
        c.[ThresholdPct] = th.[MaxChangePct],
        c.[ChangePct] = CASE
            WHEN pc.[ActualValue] IS NULL OR pc.[ActualValue] = 0 THEN NULL
            ELSE CAST(ROUND((c.[ActualValue] - pc.[ActualValue]) * 100.0 / ABS(pc.[ActualValue]), 2) AS DECIMAL (9, 2))
        END
    FROM [compliance].[ExtractControlTotal] AS c
    INNER JOIN [compliance].[ExtractRun] AS r ON c.[ExtractRunId] = r.[ExtractRunId]
    LEFT JOIN [reference].[AcademicTerm] AS rt ON r.[ReportingPeriod] = rt.[TermCode]
    OUTER APPLY (
        -- A term period compares with the latest earlier term of the same type (fall with fall).
        SELECT TOP (1) p.[ExtractRunId]
        FROM [compliance].[ExtractRun] AS p
        LEFT JOIN [reference].[AcademicTerm] AS pt ON p.[ReportingPeriod] = pt.[TermCode]
        WHERE p.[ExtractTypeCode] = r.[ExtractTypeCode] -- noqa: RF01
          AND p.[ExtractStatusCode] = 'SUCCEEDED'
          AND p.[PeriodStartDate] < r.[PeriodStartDate] -- noqa: RF01
          AND (rt.[TermType] IS NULL OR pt.[TermType] = rt.[TermType]) -- noqa: RF01
        ORDER BY p.[PeriodStartDate] DESC, p.[ExtractRunId] DESC
    ) AS pr
    LEFT JOIN [compliance].[ExtractControlTotal] AS pc
        ON pr.[ExtractRunId] = pc.[ExtractRunId]
       AND c.[ControlCode] = pc.[ControlCode]
    LEFT JOIN [compliance].[ControlThreshold] AS th
        ON r.[ExtractTypeCode] = th.[ExtractTypeCode]
       AND c.[ControlCode] = th.[ControlCode]
    WHERE c.[ExtractRunId] = @ExtractRunId;

    UPDATE c
    SET c.[OutcomeCode] = CASE
            WHEN c.[ControlKind] <> 'INFO' AND c.[ExpectedValue] IS NULL THEN 'WARN'
            WHEN c.[ControlKind] <> 'INFO'
                AND NOT (
                    (c.[ComparisonOperator] = '=' AND c.[ActualValue] = c.[ExpectedValue])
                    OR (c.[ComparisonOperator] = '>=' AND c.[ActualValue] >= c.[ExpectedValue])
                    OR (c.[ComparisonOperator] = '<=' AND c.[ActualValue] <= c.[ExpectedValue])
                ) THEN 'FAIL'
            WHEN c.[ThresholdPct] IS NOT NULL AND c.[ChangePct] IS NOT NULL AND ABS(c.[ChangePct]) > c.[ThresholdPct] THEN 'WARN'
            ELSE 'PASS'
        END,
        c.[Note] = COALESCE(c.[Note], CASE
            WHEN c.[ControlKind] <> 'INFO' AND c.[ExpectedValue] IS NULL THEN N'No expected value was available; not checked.'
            WHEN c.[ThresholdPct] IS NOT NULL AND c.[ChangePct] IS NOT NULL AND ABS(c.[ChangePct]) > c.[ThresholdPct]
                THEN CONCAT(
                    N'Changed ', c.[ChangePct], N'% against run ', c.[PriorExtractRunId], N'; the limit is ', c.[ThresholdPct], N'%.'
                )
        END)
    FROM [compliance].[ExtractControlTotal] AS c
    WHERE c.[ExtractRunId] = @ExtractRunId;

    UPDATE r
    SET r.[ValidationStatusCode] = CASE
        WHEN EXISTS (
            SELECT 1 FROM [compliance].[ExtractControlTotal] AS c WHERE c.[ExtractRunId] = r.[ExtractRunId] AND c.[OutcomeCode] = 'FAIL'
        ) THEN 'FAILED'
        WHEN EXISTS (
            SELECT 1 FROM [compliance].[ExtractControlTotal] AS c WHERE c.[ExtractRunId] = r.[ExtractRunId] AND c.[OutcomeCode] = 'WARN'
        ) THEN 'WARNING'
        ELSE 'PASSED'
    END
    FROM [compliance].[ExtractRun] AS r
    WHERE r.[ExtractRunId] = @ExtractRunId;
END;
