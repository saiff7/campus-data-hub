-- An authorized analyst resolves an identity exception by naming the J1-Sim person
-- (@MatchedIdNumber) or confirming a new person (@ConfirmNewPerson = 1). The manual decision
-- replaces the blocked decision and the exception becomes RESOLVED in one transaction; the
-- next QUEUE step approves it for retry. For AMBIGUOUS and REVIEW_REQUIRED the person must be
-- one of the stored candidates; for IDENTITY_CONFLICT any staged J1-Sim person is allowed,
-- because the analyst has established the identifier outside the system.
CREATE PROCEDURE [integration].[usp_ResolveExceptionMatch]
    @ExceptionId      BIGINT,
    @MatchedIdNumber  INT             = NULL,
    @ConfirmNewPerson BIT             = 0,
    @Note             NVARCHAR (1000) = NULL,
    @Actor            NVARCHAR (128)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @DecidedBy NVARCHAR (128) = ISNULL(NULLIF(TRIM(@Actor), N''), ORIGINAL_LOGIN());
    DECLARE @ApplicationId UNIQUEIDENTIFIER;
    DECLARE @StatusCode VARCHAR (30);
    DECLARE @ReasonCode VARCHAR (40);
    DECLARE @CurrentDecisionId BIGINT;
    DECLARE @CurrentDecisionType VARCHAR (20);
    DECLARE @CurrentEvaluationId BIGINT;
    DECLARE @CurrentCandidateCount INT;
    DECLARE @SourceHash BINARY (32);
    DECLARE @Transitions [integration].[ExceptionTransitionList];
    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        IF (@MatchedIdNumber IS NULL AND ISNULL(@ConfirmNewPerson, 0) = 0)
           OR (@MatchedIdNumber IS NOT NULL AND @ConfirmNewPerson = 1)
            THROW 50110, N'Give either the matched J1-Sim ID number or @ConfirmNewPerson = 1, not both.', 1;

        BEGIN TRANSACTION;

        SELECT
            @ApplicationId = e.[ApplicationId],
            @StatusCode = e.[ExceptionStatusCode],
            @ReasonCode = e.[ExceptionReasonCode]
        FROM [integration].[IntegrationException] AS e WITH (UPDLOCK, HOLDLOCK)
        WHERE e.[ExceptionId] = @ExceptionId;

        SELECT
            @CurrentDecisionId = d.[MatchDecisionId],
            @CurrentDecisionType = d.[DecisionTypeCode],
            @CurrentEvaluationId = d.[MatchEvaluationId],
            @CurrentCandidateCount = d.[CandidateCount],
            @SourceHash = d.[SourceHash]
        FROM [integration].[MatchDecision] AS d WITH (UPDLOCK, HOLDLOCK)
        WHERE d.[ApplicationId] = @ApplicationId
          AND d.[IsCurrent] = 1;

        IF @ApplicationId IS NULL
        BEGIN
            SET @Message = CONCAT(N'Exception ', @ExceptionId, N' does not exist or is not about an application.');
            THROW 50111, @Message, 1;
        END;

        IF @StatusCode <> 'OPEN' AND @StatusCode <> 'ASSIGNED' AND @StatusCode <> 'AWAITING_SOURCE_CORRECTION'
        BEGIN
            SET @Message = CONCAT(N'Exception ', @ExceptionId, N' is ', @StatusCode, N' and cannot be resolved.');
            THROW 50112, @Message, 1;
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM [reference].[MatchDecisionType] AS dt
            WHERE dt.[DecisionTypeCode] = @CurrentDecisionType
              AND dt.[ExceptionReasonCode] = @ReasonCode
        )
        BEGIN
            SET @Message = CONCAT(
                N'Exception ', @ExceptionId, N' (', @ReasonCode, N') does not correspond to the application''s current decision ',
                ISNULL(@CurrentDecisionType, N'(none)'), N'.'
            );
            THROW 50113, @Message, 1;
        END;

        IF @MatchedIdNumber IS NOT NULL
        BEGIN
            IF @CurrentDecisionType = 'IDENTITY_CONFLICT'
               AND NOT EXISTS (SELECT 1 FROM [staging].[Person] AS p WHERE p.[IdNumber] = @MatchedIdNumber)
            BEGIN
                SET @Message = CONCAT(N'J1-Sim ID number ', @MatchedIdNumber, N' is not a staged J1-Sim person.');
                THROW 50114, @Message, 1;
            END;

            IF @CurrentDecisionType <> 'IDENTITY_CONFLICT'
               AND NOT EXISTS (
                   SELECT 1
                   FROM [integration].[MatchCandidate] AS mc
                   WHERE mc.[MatchEvaluationId] = @CurrentEvaluationId
                     AND mc.[CandidateIdNumber] = @MatchedIdNumber
                     AND mc.[IsStagedPerson] = 1
               )
            BEGIN
                SET @Message = CONCAT(N'J1-Sim ID number ', @MatchedIdNumber, N' is not a candidate for exception ', @ExceptionId, N'.');
                THROW 50115, @Message, 1;
            END;

            IF EXISTS (
                SELECT 1
                FROM [integration].[SourceCrosswalk] AS c
                INNER JOIN [staging].[Applicant] AS a ON a.[ApplicationId] = @ApplicationId
                WHERE c.[SourceSystemCode] = 'SLATE_SIM'
                  AND c.[TargetIdNumber] = @MatchedIdNumber
                  AND c.[SourceRecordId] <> CAST(a.[SlatePersonId] AS VARCHAR (64))
            )
            BEGIN
                SET @Message = CONCAT(N'J1-Sim ID number ', @MatchedIdNumber, N' is already linked to a different Slate-Sim person.');
                THROW 50116, @Message, 1;
            END;
        END;

        UPDATE d
        SET d.[IsCurrent] = 0,
            d.[SupersededAtUtc] = @NowUtc
        FROM [integration].[MatchDecision] AS d
        WHERE d.[MatchDecisionId] = @CurrentDecisionId;

        INSERT INTO [integration].[MatchDecision] (
            [ApplicationId], [MatchEvaluationId], [BatchId], [SourceHash], [DecisionTypeCode], [RuleCode], [CandidateCount],
            [MatchedIdNumber], [ConfidenceCategory], [ConflictCode], [DecidedBy], [DecidedAtUtc], [Note], [IsCurrent]
        )
        VALUES (
            @ApplicationId, @CurrentEvaluationId, NULL, @SourceHash,
            CASE WHEN @MatchedIdNumber IS NOT NULL THEN 'MANUAL_MATCH' ELSE 'MANUAL_NEW_PERSON' END,
            NULL, @CurrentCandidateCount, @MatchedIdNumber, 'MANUAL', NULL, @DecidedBy, @NowUtc, @Note, 1
        );

        INSERT INTO @Transitions ([ExceptionId], [ToStatusCode]) VALUES (@ExceptionId, 'RESOLVED');

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Transitions,
            @ReasonText = N'Identity decision recorded by an analyst.',
            @Actor = @DecidedBy,
            @Note = @Note;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        EXEC [audit].[usp_LogError];

        THROW;
    END CATCH;
END;
