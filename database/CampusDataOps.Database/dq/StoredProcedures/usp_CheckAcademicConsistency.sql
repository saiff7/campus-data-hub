-- Academic consistency rules (docs/specifications/data-quality-rules.md), deferred from Part 2
-- until credentials were staged:
--   CRED_EARNED_CREDITS    a credential was awarded before the student had earned the program's
--                          required credits (sections graded D or better, in terms that started
--                          no later than the award term).
--   STU_STATUS_CONSISTENT  a GRADUATED student has no credential, or a WITHDRAWN student is still
--                          REGISTERED in a term that has not ended.
CREATE PROCEDURE [dq].[usp_CheckAcademicConsistency]
    @ValidationRunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Evaluations [dq].[RuleEvaluation];
    DECLARE @CheckProcedure NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

    WITH [Earned] AS (
        SELECT
            c.[CredentialAwardedId],
            SUM(CASE WHEN e.[IsAttempted] = 1 AND e.[GradePoints] >= 1.00 THEN e.[CreditHours] ELSE 0 END) AS [EarnedCredits]
        FROM [core].[vw_Credential] AS c
        INNER JOIN [reference].[AcademicTerm] AS awardterm ON c.[TermCode] = awardterm.[TermCode]
        INNER JOIN [core].[vw_Enrollment] AS e ON c.[IdNumber] = e.[IdNumber]
        INNER JOIN [reference].[AcademicTerm] AS t
            ON e.[TermCode] = t.[TermCode]
           AND awardterm.[StartDate] >= t.[StartDate]
        GROUP BY c.[CredentialAwardedId]
    )

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'CRED_EARNED_CREDITS' AS [RuleCode],
        CAST(c.[CredentialAwardedId] AS VARCHAR (20)) AS [RecordKey],
        f.[IsFailure],
        CASE
            WHEN f.[IsFailure] = 1
                THEN CONCAT('EARNED_', CAST(ISNULL(er.[EarnedCredits], 0) AS DECIMAL (6, 1)), '_OF_', c.[RequiredCredits])
        END AS [DetailCode]
    FROM [core].[vw_Credential] AS c
    LEFT JOIN [Earned] AS er ON c.[CredentialAwardedId] = er.[CredentialAwardedId]
    CROSS APPLY ( -- noqa: ST05
        SELECT CAST(CASE WHEN ISNULL(er.[EarnedCredits], 0) < c.[RequiredCredits] THEN 1 ELSE 0 END AS BIT) AS [IsFailure]
    ) AS f;

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'STU_STATUS_CONSISTENT' AS [RuleCode],
        CAST(s.[IdNumber] AS VARCHAR (20)) AS [RecordKey],
        CAST(CASE WHEN d.[DetailCode] IS NULL THEN 0 ELSE 1 END AS BIT) AS [IsFailure],
        d.[DetailCode]
    FROM [core].[vw_Student] AS s
    CROSS APPLY ( -- noqa: ST05
        SELECT CASE
            WHEN s.[StudentStatus] = 'GRADUATED'
                AND NOT EXISTS (SELECT 1 FROM [core].[vw_Credential] AS c WHERE c.[IdNumber] = s.[IdNumber])
                THEN 'GRADUATED_NO_CREDENTIAL'
            WHEN s.[StudentStatus] = 'WITHDRAWN'
                AND EXISTS (
                    SELECT 1
                    FROM [core].[vw_Enrollment] AS e
                    INNER JOIN [reference].[AcademicTerm] AS t ON e.[TermCode] = t.[TermCode]
                    WHERE e.[IdNumber] = s.[IdNumber] AND e.[RegistrationStatus] = 'REGISTERED' AND t.[EndDate] >= @Today
                )
                THEN 'WITHDRAWN_FUTURE_REGISTRATION'
        END AS [DetailCode]
    ) AS d;

    EXEC [dq].[usp_RecordRuleEvaluations]
        @ValidationRunId = @ValidationRunId, @CheckProcedure = @CheckProcedure, @Evaluations = @Evaluations;
END;
