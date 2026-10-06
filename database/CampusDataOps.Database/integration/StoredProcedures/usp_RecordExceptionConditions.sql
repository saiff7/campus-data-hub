-- Turns evaluated conditions into exception changes, idempotently
-- (docs/specifications/integration-controls.md, "System rules"):
--   present, no active exception, not held back by a closure -> raise OPEN
--   present, active exception                                -> refresh LastSeen (once per batch)
--   present, active exception RESOLVED or RETRY_READY        -> reopen
--   absent, active exception OPEN/ASSIGNED/AWAITING          -> RESOLVED, or CLOSED when an
--       identity condition was replaced by a different blocking identity decision
-- A condition is held back when a CLOSED exception for the same subject and reason was
-- closed for the same staged SourceHash (an analyst's closure of this version).
CREATE PROCEDURE [integration].[usp_RecordExceptionConditions]
    @BatchId    BIGINT,
    @Conditions [integration].[ExceptionCondition] READONLY,
    @RaisedBy   NVARCHAR (200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @ReasonText NVARCHAR (400);
    DECLARE @Transitions [integration].[ExceptionTransitionList];

    DECLARE @Raised TABLE ([ExceptionId] BIGINT NOT NULL PRIMARY KEY);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            c.[ApplicationId],
            c.[SubjectBatchId],
            c.[ExceptionReasonCode],
            c.[IsPresent],
            c.[DetailCode],
            c.[SourceHash],
            active.[ExceptionId] AS [ActiveExceptionId],
            active.[ExceptionStatusCode] AS [ActiveStatusCode],
            CAST(CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM [integration].[IntegrationException] AS closed
                    WHERE closed.[ExceptionReasonCode] = c.[ExceptionReasonCode]
                      AND closed.[ApplicationId] = c.[ApplicationId]
                      AND closed.[ExceptionStatusCode] = 'CLOSED'
                      AND closed.[SourceHash] = c.[SourceHash]
                ) THEN 1
                ELSE 0
            END AS BIT) AS [IsHeldBack],
            CAST(CASE
                WHEN EXISTS (
                    SELECT 1 FROM [reference].[MatchDecisionType] AS dt WHERE dt.[ExceptionReasonCode] = c.[ExceptionReasonCode]
                )
                AND EXISTS (
                    SELECT 1
                    FROM [integration].[MatchDecision] AS d
                    INNER JOIN [reference].[MatchDecisionType] AS dt ON d.[DecisionTypeCode] = dt.[DecisionTypeCode]
                    WHERE d.[ApplicationId] = c.[ApplicationId]
                      AND d.[IsCurrent] = 1
                      AND dt.[AllowsProcessing] = 0
                ) THEN 1
                ELSE 0
            END AS BIT) AS [IsSupersededIdentity]
        INTO #Evaluated
        FROM @Conditions AS c
        OUTER APPLY (
            SELECT TOP (1) e.[ExceptionId], e.[ExceptionStatusCode]
            FROM [integration].[IntegrationException] AS e WITH (UPDLOCK, HOLDLOCK)
            WHERE e.[ExceptionReasonCode] = c.[ExceptionReasonCode]
              AND (e.[ApplicationId] = c.[ApplicationId] OR (e.[ApplicationId] IS NULL AND c.[ApplicationId] IS NULL))
              AND (e.[SubjectBatchId] = c.[SubjectBatchId] OR (e.[SubjectBatchId] IS NULL AND c.[SubjectBatchId] IS NULL))
              AND e.[ExceptionStatusCode] <> 'REPROCESSED'
              AND e.[ExceptionStatusCode] <> 'CLOSED'
        ) AS active;

        -- Raise new exceptions.
        INSERT INTO [integration].[IntegrationException] (
            [ExceptionReasonCode], [SourceSystemCode], [ApplicationId], [SubjectBatchId], [ExceptionStatusCode],
            [Severity], [DetailCode], [SourceHash], [FirstSeenBatchId], [LastSeenBatchId], [OccurrenceCount]
        )
        OUTPUT INSERTED.[ExceptionId] INTO @Raised ([ExceptionId])
        SELECT
            ev.[ExceptionReasonCode], 'SLATE_SIM' AS [SourceSystemCode], ev.[ApplicationId], ev.[SubjectBatchId],
            'OPEN' AS [ExceptionStatusCode], r.[DefaultSeverity] AS [Severity], ev.[DetailCode], ev.[SourceHash],
            @BatchId AS [FirstSeenBatchId], @BatchId AS [LastSeenBatchId], 1 AS [OccurrenceCount]
        FROM #Evaluated AS ev
        INNER JOIN [reference].[ExceptionReason] AS r ON ev.[ExceptionReasonCode] = r.[ExceptionReasonCode]
        WHERE ev.[IsPresent] = 1
          AND ev.[ActiveExceptionId] IS NULL
          AND ev.[IsHeldBack] = 0;

        SET @ReasonText = LEFT(CONCAT(N'Raised by ', @RaisedBy), 400);

        INSERT INTO [integration].[ExceptionAction] (
            [ExceptionId], [FromStatusCode], [ToStatusCode], [BatchId], [ActionBy], [ActionAtUtc], [ReasonText]
        )
        SELECT
            r.[ExceptionId], NULL AS [FromStatusCode], 'OPEN' AS [ToStatusCode], @BatchId AS [BatchId],
            N'SYSTEM' AS [ActionBy], @NowUtc AS [ActionAtUtc], @ReasonText AS [ReasonText]
        FROM @Raised AS r;

        -- Refresh exceptions whose condition is still present; count each batch once.
        UPDATE e
        SET e.[OccurrenceCount] = e.[OccurrenceCount] + CASE WHEN e.[LastSeenBatchId] <> @BatchId THEN 1 ELSE 0 END,
            e.[LastSeenBatchId] = @BatchId,
            e.[DetailCode] = ev.[DetailCode],
            e.[SourceHash] = ev.[SourceHash],
            e.[UpdatedAtUtc] = @NowUtc
        FROM [integration].[IntegrationException] AS e
        INNER JOIN #Evaluated AS ev ON e.[ExceptionId] = ev.[ActiveExceptionId]
        -- NULL-safe change detection through correlated references, which SQLFluff RF01 cannot resolve.
        -- noqa: disable=RF01
        WHERE ev.[IsPresent] = 1
          AND EXISTS (
              SELECT ev.[DetailCode], ev.[SourceHash], @BatchId AS [LastSeenBatchId]
              EXCEPT
              SELECT e.[DetailCode], e.[SourceHash], e.[LastSeenBatchId]
          );
        -- noqa: enable=RF01

        -- Reopen resolved exceptions whose condition came back.
        INSERT INTO @Transitions ([ExceptionId], [ToStatusCode])
        SELECT ev.[ActiveExceptionId], 'OPEN' AS [ToStatusCode]
        FROM #Evaluated AS ev
        WHERE ev.[IsPresent] = 1
          AND (ev.[ActiveStatusCode] = 'RESOLVED' OR ev.[ActiveStatusCode] = 'RETRY_READY');

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Transitions, @ReasonText = N'The condition is present again.', @Actor = N'SYSTEM', @BatchId = @BatchId;

        -- Resolve exceptions whose condition disappeared.
        DELETE FROM @Transitions;
        INSERT INTO @Transitions ([ExceptionId], [ToStatusCode])
        SELECT ev.[ActiveExceptionId], 'RESOLVED' AS [ToStatusCode]
        FROM #Evaluated AS ev
        WHERE ev.[IsPresent] = 0
          AND ev.[IsSupersededIdentity] = 0
          AND (ev.[ActiveStatusCode] = 'OPEN' OR ev.[ActiveStatusCode] = 'ASSIGNED'
              OR ev.[ActiveStatusCode] = 'AWAITING_SOURCE_CORRECTION');

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Transitions, @ReasonText = N'The condition is no longer present.', @Actor = N'SYSTEM', @BatchId = @BatchId;

        -- Close identity exceptions replaced by a different blocking identity decision.
        DELETE FROM @Transitions;
        INSERT INTO @Transitions ([ExceptionId], [ToStatusCode])
        SELECT ev.[ActiveExceptionId], 'CLOSED' AS [ToStatusCode]
        FROM #Evaluated AS ev
        WHERE ev.[IsPresent] = 0
          AND ev.[IsSupersededIdentity] = 1
          AND (ev.[ActiveStatusCode] = 'OPEN' OR ev.[ActiveStatusCode] = 'ASSIGNED'
              OR ev.[ActiveStatusCode] = 'AWAITING_SOURCE_CORRECTION');

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Transitions,
            @ReasonText = N'Superseded by a different identity condition.',
            @Actor = N'SYSTEM',
            @BatchId = @BatchId,
            @ClearSourceHash = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
