-- Aid rules: the award's term is governed and its aid year matches the term's academic year;
-- disbursed aid has a REGISTERED enrollment in its term. These are consistency checks, not
-- Title IV eligibility determinations.
CREATE PROCEDURE [dq].[usp_CheckFinancialAidPeriods]
    @ValidationRunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Evaluations [dq].[RuleEvaluation];
    DECLARE @CheckProcedure NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'AID_PERIOD_VALID' AS [RuleCode],
        CAST(f.[AwardId] AS VARCHAR (20)) AS [RecordKey],
        CAST(CASE WHEN t.[TermCode] IS NULL OR f.[AidYear] <> t.[AcademicYear] THEN 1 ELSE 0 END AS BIT) AS [IsFailure],
        CASE
            WHEN t.[TermCode] IS NULL THEN 'UNKNOWN_TERM'
            WHEN f.[AidYear] <> t.[AcademicYear] THEN 'AID_YEAR_MISMATCH'
        END AS [DetailCode]
    FROM [staging].[FinancialAidAward] AS f
    LEFT JOIN [reference].[AcademicTerm] AS t ON f.[TermCode] = t.[TermCode];

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'AID_DISBURSED_ENROLLED' AS [RuleCode],
        CAST(f.[AwardId] AS VARCHAR (20)) AS [RecordKey],
        CAST(CASE WHEN e.[IdNumber] IS NULL THEN 1 ELSE 0 END AS BIT) AS [IsFailure],
        CASE WHEN e.[IdNumber] IS NULL THEN 'NO_REGISTERED_ENROLLMENT' END AS [DetailCode]
    FROM [staging].[FinancialAidAward] AS f
    OUTER APPLY (
        SELECT TOP (1) en.[IdNumber]
        FROM [staging].[Enrollment] AS en
        WHERE en.[IdNumber] = f.[IdNumber]
          AND en.[TermCode] = f.[TermCode]
          AND en.[RegistrationStatus] = 'REGISTERED'
    ) AS e
    WHERE f.[DisbursedAmount] > 0;

    EXEC [dq].[usp_RecordRuleEvaluations]
        @ValidationRunId = @ValidationRunId, @CheckProcedure = @CheckProcedure, @Evaluations = @Evaluations;
END;
