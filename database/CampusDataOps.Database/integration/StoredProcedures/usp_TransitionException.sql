-- Analyst entry point for changing one exception's status. @ExpectedFromStatusCode guards
-- against acting on a stale worklist. Identity exceptions are resolved through
-- integration.usp_ResolveExceptionMatch instead.
CREATE PROCEDURE [integration].[usp_TransitionException]
    @ExceptionId            BIGINT,
    @ToStatusCode           VARCHAR (30),
    @ReasonText             NVARCHAR (400),
    @Note                   NVARCHAR (1000) = NULL,
    @AssignedTo             NVARCHAR (128)  = NULL,
    @ExpectedFromStatusCode VARCHAR (30)    = NULL,
    @Actor                  NVARCHAR (128)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Transitions [integration].[ExceptionTransitionList];
    DECLARE @CurrentStatusCode VARCHAR (30);
    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        SET @CurrentStatusCode = (
            SELECT e.[ExceptionStatusCode] FROM [integration].[IntegrationException] AS e WHERE e.[ExceptionId] = @ExceptionId
        );

        IF @ExpectedFromStatusCode IS NOT NULL AND @CurrentStatusCode <> @ExpectedFromStatusCode
        BEGIN
            SET @Message = CONCAT(
                N'Exception ', @ExceptionId, N' is ', @CurrentStatusCode, N', not ', @ExpectedFromStatusCode, N'; refresh the worklist.'
            );
            THROW 50106, @Message, 1;
        END;

        INSERT INTO @Transitions ([ExceptionId], [ToStatusCode]) VALUES (@ExceptionId, @ToStatusCode);

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Transitions,
            @ReasonText = @ReasonText,
            @Actor = @Actor,
            @Note = @Note,
            @AssignedTo = @AssignedTo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT = 0
            EXEC [audit].[usp_LogError];

        THROW;
    END CATCH;
END;
