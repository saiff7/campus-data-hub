-- Reconciles one pipeline run at record, batch and entity level
-- (docs/specifications/integration-controls.md, "Reconciliation"). Every eligible application
-- receives exactly one outcome, in priority order: CREATED or MATCHED (written and not yet
-- reconciled), UNCHANGED (reconciled before), REJECTED (blocked, with the most severe blocking
-- reason), otherwise PENDING. Processed rows are checked against what J1-Sim actually holds.
-- Confirmed rows are marked reconciled and their REPROCESSED exceptions are CLOSED. An
-- unbalanced run raises RECONCILIATION_COUNT_MISMATCH. Running it again for the same batch
-- does nothing.
CREATE PROCEDURE [integration].[usp_ReconcileSlateToJ1]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Conditions [integration].[ExceptionCondition];
    DECLARE @Transitions [integration].[ExceptionTransitionList];
    DECLARE @TargetConfirmed INT;
    DECLARE @Processed INT;
    DECLARE @EntityMismatches INT;
    DECLARE @MismatchDetail VARCHAR (200);

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM [integration].[ReconciliationResult] AS rr WHERE rr.[BatchId] = @BatchId)
        BEGIN
            SET @RowsAffected = 0;
            RETURN;
        END;

        SELECT
            a.[ApplicationId],
            CASE
                WHEN q.[QueueId] IS NOT NULL AND q.[ReconciledBatchId] IS NULL THEN oa.[ReconciliationOutcome]
                WHEN q.[QueueId] IS NOT NULL THEN 'UNCHANGED'
                WHEN blocking.[ExceptionReasonCode] IS NOT NULL THEN 'REJECTED'
                ELSE 'PENDING'
            END AS [OutcomeCode],
            CASE WHEN q.[QueueId] IS NULL THEN blocking.[ExceptionReasonCode] END AS [ExceptionReasonCode],
            q.[QueueId],
            q.[ResultIdNumber] AS [TargetIdNumber],
            CASE
                WHEN q.[QueueId] IS NOT NULL AND q.[ReconciledBatchId] IS NULL
                    THEN CAST(CASE
                        WHEN EXISTS (
                            SELECT 1
                            FROM [integration].[vw_J1TargetStudent] AS t
                            WHERE t.[IdempotencyKey] = q.[IdempotencyKey]
                              AND t.[IdNumber] = q.[ResultIdNumber]
                              AND t.[PersonExists] = 1
                              AND t.[StudentStatus] = 'ACTIVE'
                              AND t.[ProgramCode] = q.[J1ProgramCode]
                        ) THEN 1
                        ELSE 0
                    END AS BIT)
            END AS [IsTargetConfirmed]
        INTO #Detail
        FROM [staging].[Applicant] AS a
        LEFT JOIN [integration].[OutboundStudentQueue] AS q
            ON a.[ApplicationId] = q.[ApplicationId]
           AND q.[QueueStatusCode] = 'SUCCEEDED'
        LEFT JOIN [reference].[OutboundAction] AS oa ON q.[ActionCode] = oa.[ActionCode]
        OUTER APPLY (
            SELECT TOP (1) b.[ExceptionReasonCode]
            FROM [integration].[vw_ApplicationBlock] AS b
            WHERE b.[ApplicationId] = a.[ApplicationId]
            ORDER BY CASE b.[Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, b.[ExceptionReasonCode]
        ) AS blocking
        WHERE a.[IsEligible] = 1;

        SELECT
            e.[EntityCode],
            e.[LandedKeyCount],
            e.[StagedKeyCount]
        INTO #Entity
        FROM (
            VALUES
                ('SLATE_APPLICATION',
                    (SELECT COUNT(DISTINCT r.[ApplicationId]) FROM [landing].[SlateApplicationRaw] AS r),
                    (SELECT COUNT(*) FROM [staging].[Applicant])),
                ('J1_PERSON',
                    (SELECT COUNT(DISTINCT r.[IdNumber]) FROM [landing].[J1PersonRaw] AS r),
                    (SELECT COUNT(*) FROM [staging].[Person])),
                ('J1_ENROLLMENT',
                    (SELECT COUNT(DISTINCT r.[EnrollmentId]) FROM [landing].[J1EnrollmentRaw] AS r),
                    (SELECT COUNT(*) FROM [staging].[Enrollment])),
                ('J1_FINANCIAL_AID',
                    (SELECT COUNT(DISTINCT r.[AwardId]) FROM [landing].[J1FinancialAidRaw] AS r),
                    (SELECT COUNT(*) FROM [staging].[FinancialAidAward])),
                ('J1_ACCOUNT_TRANSACTION',
                    (SELECT COUNT(DISTINCT r.[TransactionId]) FROM [landing].[J1AccountTransactionRaw] AS r),
                    (SELECT COUNT(*) FROM [staging].[AccountTransaction])),
                ('DIRECTORY_ACCOUNT',
                    (SELECT COUNT(DISTINCT r.[AccountGuid]) FROM [landing].[DirectoryAccountRaw] AS r),
                    (SELECT COUNT(*) FROM [staging].[DirectoryAccount]))
        ) AS e ([EntityCode], [LandedKeyCount], [StagedKeyCount]);

        SET @Processed = (SELECT COUNT(*) FROM #Detail AS d WHERE d.[OutcomeCode] = 'CREATED' OR d.[OutcomeCode] = 'MATCHED');
        SET @TargetConfirmed = (SELECT COUNT(*) FROM #Detail AS d WHERE d.[IsTargetConfirmed] = 1);
        SET @EntityMismatches = (SELECT COUNT(*) FROM #Entity AS e WHERE e.[LandedKeyCount] <> e.[StagedKeyCount]);
        SET @MismatchDetail = LEFT(CONCAT_WS(
            ',',
            CASE WHEN @TargetConfirmed < @Processed THEN CONCAT('TARGET_UNCONFIRMED:', @Processed - @TargetConfirmed) END,
            (SELECT STRING_AGG(CAST(e.[EntityCode] AS VARCHAR (MAX)), ',') FROM #Entity AS e WHERE e.[LandedKeyCount] <> e.[StagedKeyCount])
        ), 200);

        BEGIN TRANSACTION;

        INSERT INTO [integration].[ReconciliationDetail] (
            [BatchId], [ApplicationId], [OutcomeCode], [ExceptionReasonCode], [QueueId], [TargetIdNumber], [IsTargetConfirmed]
        )
        SELECT
            @BatchId AS [BatchId], d.[ApplicationId], d.[OutcomeCode], d.[ExceptionReasonCode],
            CASE WHEN d.[OutcomeCode] = 'CREATED' OR d.[OutcomeCode] = 'MATCHED' THEN d.[QueueId] END AS [QueueId],
            CASE WHEN d.[OutcomeCode] = 'CREATED' OR d.[OutcomeCode] = 'MATCHED' THEN d.[TargetIdNumber] END AS [TargetIdNumber],
            d.[IsTargetConfirmed]
        FROM #Detail AS d;

        SET @RowsAffected = @@ROWCOUNT;

        INSERT INTO [integration].[ReconciliationResult] (
            [BatchId], [SourceEligible], [Unchanged], [Matched], [Created], [Rejected], [Pending], [TargetConfirmed],
            [EntityMismatchCount]
        )
        SELECT
            @BatchId AS [BatchId],
            COUNT(*) AS [SourceEligible],
            SUM(CASE WHEN d.[OutcomeCode] = 'UNCHANGED' THEN 1 ELSE 0 END) AS [Unchanged],
            SUM(CASE WHEN d.[OutcomeCode] = 'MATCHED' THEN 1 ELSE 0 END) AS [Matched],
            SUM(CASE WHEN d.[OutcomeCode] = 'CREATED' THEN 1 ELSE 0 END) AS [Created],
            SUM(CASE WHEN d.[OutcomeCode] = 'REJECTED' THEN 1 ELSE 0 END) AS [Rejected],
            SUM(CASE WHEN d.[OutcomeCode] = 'PENDING' THEN 1 ELSE 0 END) AS [Pending],
            @TargetConfirmed AS [TargetConfirmed],
            @EntityMismatches AS [EntityMismatchCount]
        FROM [integration].[ReconciliationDetail] AS d
        WHERE d.[BatchId] = @BatchId;

        INSERT INTO [integration].[ReconciliationEntityCount] ([BatchId], [EntityCode], [LandedKeyCount], [StagedKeyCount])
        SELECT @BatchId AS [BatchId], e.[EntityCode], e.[LandedKeyCount], e.[StagedKeyCount]
        FROM #Entity AS e;

        UPDATE q
        SET q.[ReconciledBatchId] = @BatchId,
            q.[UpdatedAtUtc] = SYSUTCDATETIME()
        FROM [integration].[OutboundStudentQueue] AS q
        INNER JOIN #Detail AS d ON q.[QueueId] = d.[QueueId]
        WHERE d.[IsTargetConfirmed] = 1;

        INSERT INTO @Transitions ([ExceptionId], [ToStatusCode])
        SELECT e.[ExceptionId], 'CLOSED' AS [ToStatusCode]
        FROM [integration].[IntegrationException] AS e
        INNER JOIN #Detail AS d ON e.[ApplicationId] = d.[ApplicationId]
        WHERE e.[ExceptionStatusCode] = 'REPROCESSED'
          AND d.[IsTargetConfirmed] = 1;

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Transitions,
            @ReasonText = N'Reconciliation confirmed the J1-Sim record.',
            @Actor = N'SYSTEM',
            @BatchId = @BatchId,
            @ClearSourceHash = 1;

        INSERT INTO @Conditions ([SubjectBatchId], [ExceptionReasonCode], [IsPresent], [DetailCode])
        VALUES (
            @BatchId, 'RECONCILIATION_COUNT_MISMATCH',
            CASE WHEN @TargetConfirmed < @Processed OR @EntityMismatches > 0 THEN 1 ELSE 0 END,
            NULLIF(@MismatchDetail, '')
        );

        EXEC [integration].[usp_RecordExceptionConditions]
            @BatchId = @BatchId, @Conditions = @Conditions, @RaisedBy = N'integration.usp_ReconcileSlateToJ1';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
