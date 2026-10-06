-- Records which applications are evaluated in this batch and every J1-Sim person each match
-- rule finds for them (docs/specifications/matching-rules.md). An application is evaluated
-- when it is eligible, not yet written to J1-Sim, not blocked by a validation exception, and
-- has no current decision, a changed source version, or a blocked automatic decision.
-- All rules are evaluated and stored; usp_ResolveDeterministicMatches makes the decision.
CREATE PROCEDURE [integration].[usp_BuildApplicantMatchCandidates]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO [integration].[MatchEvaluation] ([BatchId], [ApplicationId], [SourceHash])
        SELECT @BatchId AS [BatchId], a.[ApplicationId], a.[SourceHash]
        FROM [staging].[Applicant] AS a
        LEFT JOIN [integration].[MatchDecision] AS d
            ON a.[ApplicationId] = d.[ApplicationId]
           AND d.[IsCurrent] = 1
        LEFT JOIN [reference].[MatchDecisionType] AS dt ON d.[DecisionTypeCode] = dt.[DecisionTypeCode]
        WHERE a.[IsEligible] = 1
          AND NOT EXISTS (SELECT 1 FROM [integration].[vw_IntegratedApplication] AS ia WHERE ia.[ApplicationId] = a.[ApplicationId])
          AND NOT EXISTS (
              SELECT 1
              FROM [integration].[vw_ApplicationBlock] AS b
              WHERE b.[ApplicationId] = a.[ApplicationId]
                AND (b.[ReasonCategory] = 'VALIDATION' OR b.[ReasonCategory] = 'REFERENCE')
          )
          AND (
              d.[MatchDecisionId] IS NULL
              OR d.[SourceHash] <> a.[SourceHash]
              OR (dt.[AllowsProcessing] = 0 AND dt.[IsManual] = 0)
          )
          AND NOT EXISTS (
              SELECT 1 FROM [integration].[MatchEvaluation] AS me WHERE me.[BatchId] = @BatchId AND me.[ApplicationId] = a.[ApplicationId]
          );

        SET @RowsAffected = @@ROWCOUNT;

        WITH [Found] AS (
            SELECT me.[MatchEvaluationId], 'CROSSWALK' AS [RuleCode], c.[TargetIdNumber] AS [CandidateIdNumber]
            FROM [integration].[MatchEvaluation] AS me
            INNER JOIN [staging].[Applicant] AS a ON me.[ApplicationId] = a.[ApplicationId]
            INNER JOIN [integration].[SourceCrosswalk] AS c
                ON c.[SourceSystemCode] = 'SLATE_SIM'
               AND c.[SourceRecordId] = CAST(a.[SlatePersonId] AS VARCHAR (64))
            WHERE me.[BatchId] = @BatchId

            UNION ALL

            SELECT me.[MatchEvaluationId], 'SIS_ID' AS [RuleCode], p.[IdNumber] AS [CandidateIdNumber]
            FROM [integration].[MatchEvaluation] AS me
            INNER JOIN [staging].[Applicant] AS a ON me.[ApplicationId] = a.[ApplicationId]
            INNER JOIN [staging].[Person] AS p ON a.[SisIdClaim] = p.[IdNumber]
            WHERE me.[BatchId] = @BatchId

            UNION ALL

            SELECT me.[MatchEvaluationId], 'EMAIL_DOB' AS [RuleCode], p.[IdNumber] AS [CandidateIdNumber]
            FROM [integration].[MatchEvaluation] AS me
            INNER JOIN [staging].[Applicant] AS a ON me.[ApplicationId] = a.[ApplicationId]
            INNER JOIN [staging].[Person] AS p
                ON a.[EmailStd] = p.[EmailStd]
               AND a.[BirthDate] = p.[BirthDate]
            WHERE me.[BatchId] = @BatchId

            UNION ALL

            SELECT me.[MatchEvaluationId], 'NAME_DOB_POSTAL' AS [RuleCode], p.[IdNumber] AS [CandidateIdNumber]
            FROM [integration].[MatchEvaluation] AS me
            INNER JOIN [staging].[Applicant] AS a ON me.[ApplicationId] = a.[ApplicationId]
            INNER JOIN [staging].[Person] AS p
                ON a.[LastNameStd] = p.[LastNameStd]
               AND a.[FirstNameStd] = p.[FirstNameStd]
               AND a.[BirthDate] = p.[BirthDate]
               AND a.[PostalCode5] = p.[PostalCode5]
            WHERE me.[BatchId] = @BatchId
        )

        INSERT INTO [integration].[MatchCandidate] (
            [MatchEvaluationId], [RuleCode], [CandidateIdNumber], [IsStagedPerson], [MatchedOnSisId], [MatchedOnEmail],
            [MatchedOnBirthDate], [MatchedOnName], [MatchedOnPostalCode]
        )
        SELECT
            f.[MatchEvaluationId],
            f.[RuleCode],
            f.[CandidateIdNumber],
            CAST(CASE WHEN p.[IdNumber] IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS [IsStagedPerson],
            CAST(CASE WHEN a.[SisIdClaim] = f.[CandidateIdNumber] THEN 1 ELSE 0 END AS BIT) AS [MatchedOnSisId],
            CAST(CASE WHEN a.[EmailStd] = p.[EmailStd] THEN 1 ELSE 0 END AS BIT) AS [MatchedOnEmail],
            CAST(CASE WHEN a.[BirthDate] = p.[BirthDate] THEN 1 ELSE 0 END AS BIT) AS [MatchedOnBirthDate],
            CAST(CASE WHEN a.[LastNameStd] = p.[LastNameStd] AND a.[FirstNameStd] = p.[FirstNameStd] THEN 1 ELSE 0 END AS BIT)
                AS [MatchedOnName],
            CAST(CASE WHEN a.[PostalCode5] = p.[PostalCode5] THEN 1 ELSE 0 END AS BIT) AS [MatchedOnPostalCode]
        FROM [Found] AS f
        INNER JOIN [integration].[MatchEvaluation] AS me ON f.[MatchEvaluationId] = me.[MatchEvaluationId]
        INNER JOIN [staging].[Applicant] AS a ON me.[ApplicationId] = a.[ApplicationId]
        LEFT JOIN [staging].[Person] AS p ON f.[CandidateIdNumber] = p.[IdNumber]
        WHERE NOT EXISTS (
            SELECT 1
            FROM [integration].[MatchCandidate] AS mc
            WHERE mc.[MatchEvaluationId] = f.[MatchEvaluationId]
              AND mc.[RuleCode] = f.[RuleCode]
              AND mc.[CandidateIdNumber] = f.[CandidateIdNumber]
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
