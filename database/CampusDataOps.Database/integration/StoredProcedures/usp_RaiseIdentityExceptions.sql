-- Raises or resolves identity exceptions from current match decisions: a blocked decision type
-- names its exception reason in reference.MatchDecisionType. Applications blocked by a
-- validation exception are skipped, so their identity exceptions are left as they are.
CREATE PROCEDURE [integration].[usp_RaiseIdentityExceptions]
    @BatchId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Conditions [integration].[ExceptionCondition];

    BEGIN TRY
        WITH [IdentityReason] AS (
            SELECT DISTINCT t.[ExceptionReasonCode]
            FROM [reference].[MatchDecisionType] AS t
            WHERE t.[ExceptionReasonCode] IS NOT NULL
        )

        INSERT INTO @Conditions ([ApplicationId], [ExceptionReasonCode], [IsPresent], [DetailCode], [SourceHash])
        SELECT
            a.[ApplicationId],
            reasons.[ExceptionReasonCode],
            CAST(CASE WHEN dt.[ExceptionReasonCode] = reasons.[ExceptionReasonCode] THEN 1 ELSE 0 END AS BIT) AS [IsPresent],
            CASE
                WHEN dt.[ExceptionReasonCode] = reasons.[ExceptionReasonCode]
                    THEN ISNULL(d.[ConflictCode], CONCAT('RULE:', d.[RuleCode], ',CANDIDATES:', d.[CandidateCount]))
            END AS [DetailCode],
            a.[SourceHash]
        FROM [staging].[Applicant] AS a
        INNER JOIN [integration].[MatchDecision] AS d
            ON a.[ApplicationId] = d.[ApplicationId]
           AND d.[IsCurrent] = 1
        INNER JOIN [reference].[MatchDecisionType] AS dt ON d.[DecisionTypeCode] = dt.[DecisionTypeCode]
        CROSS JOIN [IdentityReason] AS reasons
        WHERE a.[IsEligible] = 1
          AND NOT EXISTS (SELECT 1 FROM [integration].[vw_IntegratedApplication] AS ia WHERE ia.[ApplicationId] = a.[ApplicationId])
          AND NOT EXISTS (
              SELECT 1
              FROM [integration].[vw_ApplicationBlock] AS b
              WHERE b.[ApplicationId] = a.[ApplicationId]
                AND (b.[ReasonCategory] = 'VALIDATION' OR b.[ReasonCategory] = 'REFERENCE')
          );

        EXEC [integration].[usp_RecordExceptionConditions]
            @BatchId = @BatchId, @Conditions = @Conditions, @RaisedBy = N'integration.usp_RaiseIdentityExceptions';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
