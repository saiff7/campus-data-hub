-- Queues every ready application for the J1-Sim import interface
-- (docs/specifications/integration-controls.md, "Outbound student queue"). Ready means
-- eligible, not yet written, a current decision that allows processing, and not blocked
-- (integration.vw_ApplicationBlock). A matched person who is already an ACTIVE student raises
-- ALREADY_MATRICULATED instead. The idempotency key identifies application, action and target,
-- so re-queueing the same decision reuses its row and a changed decision cancels the old one.
CREATE PROCEDURE [integration].[usp_QueueAcceptedApplicants]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @Conditions [integration].[ExceptionCondition];

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Matched applications whose person is already an active student cannot be admitted.
        INSERT INTO @Conditions ([ApplicationId], [ExceptionReasonCode], [IsPresent], [DetailCode], [SourceHash])
        SELECT
            a.[ApplicationId],
            'ALREADY_MATRICULATED' AS [ExceptionReasonCode],
            CAST(CASE WHEN p.[StudentStatus] = 'ACTIVE' THEN 1 ELSE 0 END AS BIT) AS [IsPresent],
            CASE WHEN p.[StudentStatus] = 'ACTIVE' THEN CONCAT('ID_NUMBER:', p.[IdNumber]) END AS [DetailCode],
            a.[SourceHash]
        FROM [staging].[Applicant] AS a
        INNER JOIN [integration].[MatchDecision] AS d
            ON a.[ApplicationId] = d.[ApplicationId]
           AND d.[IsCurrent] = 1
        INNER JOIN [reference].[MatchDecisionType] AS dt
            ON d.[DecisionTypeCode] = dt.[DecisionTypeCode]
           AND dt.[AllowsProcessing] = 1
        INNER JOIN [staging].[Person] AS p ON d.[MatchedIdNumber] = p.[IdNumber]
        WHERE a.[IsEligible] = 1
          AND NOT EXISTS (SELECT 1 FROM [integration].[vw_IntegratedApplication] AS ia WHERE ia.[ApplicationId] = a.[ApplicationId]);

        EXEC [integration].[usp_RecordExceptionConditions]
            @BatchId = @BatchId, @Conditions = @Conditions, @RaisedBy = N'integration.usp_QueueAcceptedApplicants';

        SELECT
            a.[ApplicationId],
            a.[SlatePersonId],
            d.[MatchDecisionId],
            act.[ActionCode],
            d.[MatchedIdNumber] AS [TargetIdNumber],
            a.[FirstNameRaw],
            a.[MiddleNameRaw],
            a.[LastNameRaw],
            a.[BirthDate],
            a.[EmailStd],
            a.[PhoneStd],
            a.[AddressLine1],
            a.[City],
            a.[StateCode],
            a.[PostalCodeRaw],
            a.[J1ProgramCode],
            a.[EntryTermCode],
            a.[ResidencyCode],
            HASHBYTES('SHA2_256', CONCAT(
                'SLATE_SIM|', LOWER(CAST(a.[ApplicationId] AS VARCHAR (36))), '|', act.[ActionCode], '|',
                CAST(d.[MatchedIdNumber] AS VARCHAR (12))
            )) AS [IdempotencyKey]
        INTO #Ready
        FROM [staging].[Applicant] AS a
        INNER JOIN [integration].[MatchDecision] AS d
            ON a.[ApplicationId] = d.[ApplicationId]
           AND d.[IsCurrent] = 1
        INNER JOIN [reference].[MatchDecisionType] AS dt
            ON d.[DecisionTypeCode] = dt.[DecisionTypeCode]
           AND dt.[AllowsProcessing] = 1
        LEFT JOIN [staging].[Person] AS p ON d.[MatchedIdNumber] = p.[IdNumber]
        -- The action is derived once per row and used in the key, the select list and the filter.
        CROSS APPLY ( -- noqa: ST05
            SELECT CASE
                WHEN d.[MatchedIdNumber] IS NULL THEN 'CREATE_PERSON_STUDENT'
                WHEN p.[HasStudentRecord] = 0 THEN 'CREATE_STUDENT'
                WHEN p.[StudentStatus] <> 'ACTIVE' THEN 'READMIT_STUDENT'
            END AS [ActionCode]
        ) AS act
        WHERE a.[IsEligible] = 1
          AND act.[ActionCode] IS NOT NULL
          AND (d.[MatchedIdNumber] IS NULL OR p.[IdNumber] IS NOT NULL)
          AND NOT EXISTS (SELECT 1 FROM [integration].[vw_IntegratedApplication] AS ia WHERE ia.[ApplicationId] = a.[ApplicationId])
          AND NOT EXISTS (SELECT 1 FROM [integration].[vw_ApplicationBlock] AS b WHERE b.[ApplicationId] = a.[ApplicationId]);

        -- Cancel unsent rows that no longer match a ready decision.
        UPDATE q
        SET q.[QueueStatusCode] = 'CANCELLED',
            q.[UpdatedAtUtc] = @NowUtc
        FROM [integration].[OutboundStudentQueue] AS q
        INNER JOIN [reference].[OutboundQueueStatus] AS s
            ON q.[QueueStatusCode] = s.[QueueStatusCode]
           AND s.[IsSendable] = 1
        WHERE NOT EXISTS (SELECT 1 FROM #Ready AS r WHERE r.[IdempotencyKey] = q.[IdempotencyKey]);

        SET @RowsAffected = @@ROWCOUNT;

        -- Refresh unsent rows of the same decision, and reactivate a cancelled row with the same key.
        UPDATE q
        SET q.[QueueStatusCode] = CASE WHEN q.[QueueStatusCode] = 'CANCELLED' THEN 'PENDING' ELSE q.[QueueStatusCode] END,
            q.[AttemptCount] = CASE WHEN q.[QueueStatusCode] = 'CANCELLED' THEN 0 ELSE q.[AttemptCount] END,
            q.[RetryGeneration] = q.[RetryGeneration] + CASE WHEN q.[QueueStatusCode] = 'CANCELLED' THEN 1 ELSE 0 END,
            q.[MatchDecisionId] = r.[MatchDecisionId],
            q.[FirstName] = r.[FirstNameRaw],
            q.[MiddleName] = r.[MiddleNameRaw],
            q.[LastName] = r.[LastNameRaw],
            q.[BirthDate] = r.[BirthDate],
            q.[Email] = r.[EmailStd],
            q.[Phone] = r.[PhoneStd],
            q.[AddressLine1] = r.[AddressLine1],
            q.[City] = r.[City],
            q.[StateCode] = r.[StateCode],
            q.[PostalCode] = r.[PostalCodeRaw],
            q.[J1ProgramCode] = r.[J1ProgramCode],
            q.[EntryTermCode] = r.[EntryTermCode],
            q.[ResidencyCode] = r.[ResidencyCode],
            q.[UpdatedAtUtc] = @NowUtc
        FROM [integration].[OutboundStudentQueue] AS q
        INNER JOIN #Ready AS r ON q.[IdempotencyKey] = r.[IdempotencyKey]
        INNER JOIN [reference].[OutboundQueueStatus] AS s ON q.[QueueStatusCode] = s.[QueueStatusCode]
        WHERE (s.[IsSendable] = 1 OR q.[QueueStatusCode] = 'CANCELLED')
          AND (q.[QueueStatusCode] = 'CANCELLED' OR q.[MatchDecisionId] <> r.[MatchDecisionId]);

        SET @RowsAffected += @@ROWCOUNT;

        INSERT INTO [integration].[OutboundStudentQueue] (
            [IdempotencyKey], [ApplicationId], [SlatePersonId], [ActionCode], [TargetIdNumber], [MatchDecisionId],
            [FirstName], [MiddleName], [LastName], [BirthDate], [Email], [Phone], [AddressLine1], [City], [StateCode],
            [PostalCode], [J1ProgramCode], [EntryTermCode], [ResidencyCode], [QueueStatusCode], [QueuedBatchId]
        )
        SELECT
            r.[IdempotencyKey], r.[ApplicationId], r.[SlatePersonId], r.[ActionCode], r.[TargetIdNumber], r.[MatchDecisionId],
            r.[FirstNameRaw], r.[MiddleNameRaw], r.[LastNameRaw], r.[BirthDate], r.[EmailStd], r.[PhoneStd],
            r.[AddressLine1], r.[City], r.[StateCode], r.[PostalCodeRaw], r.[J1ProgramCode], r.[EntryTermCode],
            r.[ResidencyCode], 'PENDING' AS [QueueStatusCode], @BatchId AS [QueuedBatchId]
        FROM #Ready AS r
        WHERE NOT EXISTS (SELECT 1 FROM [integration].[OutboundStudentQueue] AS q WHERE q.[IdempotencyKey] = r.[IdempotencyKey]);

        SET @RowsAffected += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
