-- Applies the decision table (docs/specifications/matching-rules.md) to this batch's
-- evaluations. The deciding rule is the highest-priority automatic rule with candidates, read
-- from reference.MatchRule. A new decision row is written only when the outcome or the source
-- version differs from the current decision, so an unchanged rerun writes nothing.
CREATE PROCEDURE [integration].[usp_ResolveDeterministicMatches]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

    BEGIN TRY
        SELECT
            me.[MatchEvaluationId],
            me.[ApplicationId],
            me.[SourceHash],
            deciding.[RuleCode] AS [DecidingRuleCode],
            deciding.[Priority] AS [DecidingPriority],
            deciding.[ConfidenceCategory] AS [DecidingConfidence],
            deciding.[CandidateCount] AS [DecidingCount],
            deciding.[CandidateIdNumber] AS [DecidingIdNumber],
            review.[CandidateCount] AS [ReviewCount],
            allc.[CandidateCount] AS [TotalCandidateCount],
            CASE
                WHEN EXISTS (
                    SELECT 1 FROM [integration].[MatchCandidate] AS mc
                    WHERE mc.[MatchEvaluationId] = me.[MatchEvaluationId] AND mc.[RuleCode] = 'CROSSWALK' AND mc.[IsStagedPerson] = 0
                ) THEN 'CROSSWALK_TARGET_MISSING'
                WHEN a.[IsSisIdClaimValid] = 0 THEN 'SIS_ID_INVALID_FORMAT'
                WHEN a.[SisIdClaim] IS NOT NULL AND NOT EXISTS (
                    SELECT 1 FROM [integration].[MatchCandidate] AS mc
                    WHERE mc.[MatchEvaluationId] = me.[MatchEvaluationId] AND mc.[RuleCode] = 'SIS_ID'
                ) THEN 'SIS_ID_NOT_FOUND'
                WHEN EXISTS (
                    SELECT 1 FROM [integration].[MatchCandidate] AS mc
                    WHERE mc.[MatchEvaluationId] = me.[MatchEvaluationId] AND mc.[RuleCode] = 'SIS_ID' AND mc.[MatchedOnBirthDate] = 0
                ) THEN 'SIS_ID_BIRTH_DATE_MISMATCH'
                WHEN EXISTS (
                    SELECT 1 FROM [staging].[Applicant] AS other
                    WHERE other.[SisIdClaim] = a.[SisIdClaim] AND other.[SlatePersonId] <> a.[SlatePersonId]
                ) THEN 'SIS_ID_CLAIMED_BY_MULTIPLE'
                -- A lower automatic rule found candidates, none of which is the deciding person.
                WHEN deciding.[CandidateCount] = 1 AND EXISTS (
                    SELECT 1
                    FROM [integration].[MatchCandidate] AS lower_rule
                    INNER JOIN [reference].[MatchRule] AS r ON lower_rule.[RuleCode] = r.[RuleCode]
                    WHERE lower_rule.[MatchEvaluationId] = me.[MatchEvaluationId]
                      AND r.[IsAutoMatchEligible] = 1
                      AND r.[Priority] > deciding.[Priority]
                      AND NOT EXISTS (
                          SELECT 1
                          FROM [integration].[MatchCandidate] AS same_person
                          WHERE same_person.[MatchEvaluationId] = lower_rule.[MatchEvaluationId]
                            AND same_person.[RuleCode] = lower_rule.[RuleCode]
                            AND same_person.[CandidateIdNumber] = deciding.[CandidateIdNumber]
                      )
                ) THEN 'RULES_DISAGREE'
            END AS [ConflictCode]
        INTO #Evaluated
        FROM [integration].[MatchEvaluation] AS me
        INNER JOIN [staging].[Applicant] AS a ON me.[ApplicationId] = a.[ApplicationId]
        OUTER APPLY (
            SELECT TOP (1)
                r.[RuleCode],
                r.[Priority],
                r.[ConfidenceCategory],
                COUNT(*) AS [CandidateCount],
                MIN(mc.[CandidateIdNumber]) AS [CandidateIdNumber]
            FROM [integration].[MatchCandidate] AS mc
            INNER JOIN [reference].[MatchRule] AS r ON mc.[RuleCode] = r.[RuleCode]
            WHERE mc.[MatchEvaluationId] = me.[MatchEvaluationId]
              AND r.[IsAutoMatchEligible] = 1
            GROUP BY r.[RuleCode], r.[Priority], r.[ConfidenceCategory]
            ORDER BY r.[Priority]
        ) AS deciding
        OUTER APPLY (
            SELECT COUNT(*) AS [CandidateCount]
            FROM [integration].[MatchCandidate] AS mc
            INNER JOIN [reference].[MatchRule] AS r ON mc.[RuleCode] = r.[RuleCode]
            WHERE mc.[MatchEvaluationId] = me.[MatchEvaluationId]
              AND r.[IsAutoMatchEligible] = 0
        ) AS review
        OUTER APPLY (
            SELECT COUNT(DISTINCT mc.[CandidateIdNumber]) AS [CandidateCount]
            FROM [integration].[MatchCandidate] AS mc
            WHERE mc.[MatchEvaluationId] = me.[MatchEvaluationId]
        ) AS allc
        WHERE me.[BatchId] = @BatchId;

        SELECT
            ev.[ApplicationId],
            ev.[MatchEvaluationId],
            ev.[SourceHash],
            d.[DecisionTypeCode],
            d.[RuleCode],
            d.[CandidateCount],
            d.[MatchedIdNumber],
            d.[ConfidenceCategory],
            ev.[ConflictCode]
        INTO #Decided
        FROM #Evaluated AS ev
        -- The decision table, evaluated once per row in one place.
        CROSS APPLY ( -- noqa: ST05
            SELECT
                CASE
                    WHEN ev.[ConflictCode] IS NOT NULL THEN 'IDENTITY_CONFLICT'
                    WHEN ev.[DecidingCount] >= 2 THEN 'AMBIGUOUS'
                    WHEN ev.[DecidingCount] = 1 THEN 'AUTO_MATCH'
                    WHEN ev.[ReviewCount] >= 1 THEN 'REVIEW_REQUIRED'
                    ELSE 'NEW_PERSON'
                END AS [DecisionTypeCode],
                CASE
                    WHEN ev.[ConflictCode] IS NOT NULL THEN NULL
                    WHEN ev.[DecidingCount] >= 1 THEN ev.[DecidingRuleCode]
                    WHEN ev.[ReviewCount] >= 1 THEN 'NAME_DOB_POSTAL'
                END AS [RuleCode],
                CASE
                    WHEN ev.[ConflictCode] IS NOT NULL THEN ev.[TotalCandidateCount]
                    WHEN ev.[DecidingCount] >= 1 THEN ev.[DecidingCount]
                    ELSE ev.[ReviewCount]
                END AS [CandidateCount],
                CASE WHEN ev.[ConflictCode] IS NULL AND ev.[DecidingCount] = 1 THEN ev.[DecidingIdNumber] END AS [MatchedIdNumber],
                CASE
                    WHEN ev.[ConflictCode] IS NOT NULL THEN 'NONE'
                    WHEN ev.[DecidingCount] >= 1 THEN ev.[DecidingConfidence]
                    WHEN ev.[ReviewCount] >= 1 THEN 'REVIEW'
                    ELSE 'NONE'
                END AS [ConfidenceCategory]
        ) AS d;

        -- Keep only outcomes that differ from the current decision.
        DELETE dc
        FROM #Decided AS dc
        INNER JOIN [integration].[MatchDecision] AS cur
            ON dc.[ApplicationId] = cur.[ApplicationId]
           AND cur.[IsCurrent] = 1
        -- NULL-safe comparison through correlated references, which SQLFluff RF01 cannot resolve.
        -- noqa: disable=RF01
        WHERE NOT EXISTS (
            SELECT dc.[DecisionTypeCode], dc.[RuleCode], dc.[CandidateCount], dc.[MatchedIdNumber], dc.[ConflictCode], dc.[SourceHash]
            EXCEPT
            SELECT cur.[DecisionTypeCode], cur.[RuleCode], cur.[CandidateCount], cur.[MatchedIdNumber], cur.[ConflictCode], cur.[SourceHash]
        );
        -- noqa: enable=RF01

        BEGIN TRANSACTION;

        UPDATE cur
        SET cur.[IsCurrent] = 0,
            cur.[SupersededAtUtc] = @NowUtc
        FROM [integration].[MatchDecision] AS cur
        INNER JOIN #Decided AS dc ON cur.[ApplicationId] = dc.[ApplicationId]
        WHERE cur.[IsCurrent] = 1;

        INSERT INTO [integration].[MatchDecision] (
            [ApplicationId], [MatchEvaluationId], [BatchId], [SourceHash], [DecisionTypeCode], [RuleCode],
            [CandidateCount], [MatchedIdNumber], [ConfidenceCategory], [ConflictCode], [DecidedBy], [DecidedAtUtc], [IsCurrent]
        )
        SELECT
            dc.[ApplicationId], dc.[MatchEvaluationId], @BatchId AS [BatchId], dc.[SourceHash], dc.[DecisionTypeCode],
            dc.[RuleCode], dc.[CandidateCount], dc.[MatchedIdNumber], dc.[ConfidenceCategory], dc.[ConflictCode],
            N'SYSTEM' AS [DecidedBy], @NowUtc AS [DecidedAtUtc], 1 AS [IsCurrent]
        FROM #Decided AS dc;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
