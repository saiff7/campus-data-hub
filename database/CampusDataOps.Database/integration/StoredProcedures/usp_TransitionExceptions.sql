-- Applies a set of exception status changes atomically and records one ExceptionAction per
-- change. Every change must be listed in reference.ExceptionStatusTransition. An identity
-- exception may become RESOLVED only when the application's current match decision allows
-- processing, so an identity problem cannot be "resolved" without an identity decision.
-- @ClearSourceHash = 1 is used by system closures so they never hold a condition back.
CREATE PROCEDURE [integration].[usp_TransitionExceptions]
    @Transitions     [integration].[ExceptionTransitionList] READONLY,
    @ReasonText      NVARCHAR (400),
    @Actor           NVARCHAR (128)  = NULL,
    @Note            NVARCHAR (1000) = NULL,
    @BatchId         BIGINT          = NULL,
    @AssignedTo      NVARCHAR (128)  = NULL,
    @ClearSourceHash BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @ActionBy NVARCHAR (128) = ISNULL(NULLIF(TRIM(@Actor), N''), ORIGINAL_LOGIN());
    DECLARE @Requested INT = (SELECT COUNT(*) FROM @Transitions);
    DECLARE @Changed INT;
    DECLARE @Message NVARCHAR (400);
    DECLARE @FirstBadId BIGINT;

    DECLARE @Applied TABLE (
        [ExceptionId]    BIGINT       NOT NULL PRIMARY KEY,
        [FromStatusCode] VARCHAR (30) NOT NULL,
        [ToStatusCode]   VARCHAR (30) NOT NULL
    );

    BEGIN TRY
        IF NULLIF(TRIM(@ReasonText), N'') IS NULL
            THROW 50100, N'A reason is required for every exception status change.', 1;

        IF @Requested = 0
            RETURN;

        BEGIN TRANSACTION;

        SELECT
            t.[ExceptionId],
            t.[ToStatusCode],
            e.[ExceptionStatusCode] AS [FromStatusCode],
            e.[ExceptionReasonCode],
            e.[ApplicationId]
        INTO #Requested
        FROM @Transitions AS t
        LEFT JOIN [integration].[IntegrationException] AS e WITH (UPDLOCK, HOLDLOCK)
            ON t.[ExceptionId] = e.[ExceptionId];

        SET @FirstBadId = (SELECT MIN(r.[ExceptionId]) FROM #Requested AS r WHERE r.[FromStatusCode] IS NULL);
        IF @FirstBadId IS NOT NULL
        BEGIN
            SET @Message = CONCAT(N'Exception ', @FirstBadId, N' does not exist.');
            THROW 50101, @Message, 1;
        END;

        SET @FirstBadId = (
            SELECT MIN(r.[ExceptionId])
            FROM #Requested AS r
            WHERE NOT EXISTS (
                SELECT 1
                FROM [reference].[ExceptionStatusTransition] AS st
                WHERE st.[FromStatusCode] = r.[FromStatusCode]
                  AND st.[ToStatusCode] = r.[ToStatusCode]
            )
        );
        IF @FirstBadId IS NOT NULL
        BEGIN
            SET @Message = (
                SELECT CONCAT(N'Exception ', r.[ExceptionId], N' cannot move from ', r.[FromStatusCode], N' to ', r.[ToStatusCode], N'.')
                FROM #Requested AS r
                WHERE r.[ExceptionId] = @FirstBadId
            );
            THROW 50102, @Message, 1;
        END;

        IF EXISTS (SELECT 1 FROM #Requested AS r WHERE r.[ToStatusCode] = 'ASSIGNED')
           AND NULLIF(TRIM(@AssignedTo), N'') IS NULL
            THROW 50103, N'Assigning an exception requires the analyst it is assigned to.', 1;

        SET @FirstBadId = (
            SELECT MIN(r.[ExceptionId])
            FROM #Requested AS r
            WHERE r.[ToStatusCode] = 'RESOLVED'
              AND EXISTS (
                  SELECT 1 FROM [reference].[MatchDecisionType] AS dt WHERE dt.[ExceptionReasonCode] = r.[ExceptionReasonCode]
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM [integration].[MatchDecision] AS d
                  INNER JOIN [reference].[MatchDecisionType] AS dt ON d.[DecisionTypeCode] = dt.[DecisionTypeCode]
                  WHERE d.[ApplicationId] = r.[ApplicationId]
                    AND d.[IsCurrent] = 1
                    AND dt.[AllowsProcessing] = 1
              )
        );
        IF @FirstBadId IS NOT NULL
        BEGIN
            SET @Message = CONCAT(
                N'Identity exception ', @FirstBadId,
                N' cannot be resolved without an identity decision; use integration.usp_ResolveExceptionMatch.'
            );
            THROW 50104, @Message, 1;
        END;

        UPDATE e
        SET e.[ExceptionStatusCode] = r.[ToStatusCode],
            e.[AssignedTo] = CASE
                WHEN r.[ToStatusCode] = 'ASSIGNED' THEN TRIM(@AssignedTo)
                WHEN r.[ToStatusCode] = 'OPEN' THEN NULL
                ELSE e.[AssignedTo]
            END,
            e.[SourceHash] = CASE WHEN @ClearSourceHash = 1 THEN NULL ELSE e.[SourceHash] END,
            e.[UpdatedAtUtc] = @NowUtc
        OUTPUT INSERTED.[ExceptionId], DELETED.[ExceptionStatusCode], INSERTED.[ExceptionStatusCode]
        INTO @Applied ([ExceptionId], [FromStatusCode], [ToStatusCode])
        FROM [integration].[IntegrationException] AS e
        INNER JOIN #Requested AS r
            ON e.[ExceptionId] = r.[ExceptionId]
           AND e.[ExceptionStatusCode] = r.[FromStatusCode];

        SET @Changed = @@ROWCOUNT;
        IF @Changed <> @Requested
        BEGIN
            SET @Message = CONCAT(@Requested - @Changed, N' exceptions changed status concurrently; no change was applied.');
            THROW 50105, @Message, 1;
        END;

        INSERT INTO [integration].[ExceptionAction] (
            [ExceptionId], [FromStatusCode], [ToStatusCode], [BatchId], [ActionBy], [ActionAtUtc], [ReasonText], [Note]
        )
        SELECT
            a.[ExceptionId], a.[FromStatusCode], a.[ToStatusCode], @BatchId AS [BatchId], @ActionBy AS [ActionBy],
            @NowUtc AS [ActionAtUtc], @ReasonText AS [ReasonText], @Note AS [Note]
        FROM @Applied AS a;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
