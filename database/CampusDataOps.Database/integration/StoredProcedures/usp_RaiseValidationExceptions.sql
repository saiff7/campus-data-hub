-- Evaluates the validation reasons (docs/specifications/integration-controls.md) for every
-- eligible application not yet written to J1-Sim, and closes the active exceptions of
-- applications that are no longer eligible (for example, withdrawn).
CREATE PROCEDURE [integration].[usp_RaiseValidationExceptions]
    @BatchId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Conditions [integration].[ExceptionCondition];
    DECLARE @Transitions [integration].[ExceptionTransitionList];

    BEGIN TRY
        INSERT INTO @Conditions ([ApplicationId], [ExceptionReasonCode], [IsPresent], [DetailCode], [SourceHash])
        SELECT
            a.[ApplicationId],
            c.[ExceptionReasonCode],
            c.[IsPresent],
            CASE WHEN c.[IsPresent] = 1 THEN c.[DetailCode] END AS [DetailCode],
            a.[SourceHash]
        FROM [staging].[Applicant] AS a
        CROSS APPLY (
            VALUES
                ('MISSING_REQUIRED_FIELD',
                    CAST(CASE WHEN a.[MissingRequiredFields] IS NOT NULL THEN 1 ELSE 0 END AS BIT),
                    a.[MissingRequiredFields]),
                ('INVALID_PROGRAM',
                    CAST(CASE WHEN a.[ProgramValidationCode] = 'NOT_IN_CROSSWALK' OR a.[ProgramValidationCode] = 'INACTIVE'
                        THEN 1 ELSE 0 END AS BIT),
                    a.[ProgramValidationCode]),
                ('INVALID_ENTRY_TERM',
                    CAST(CASE WHEN a.[TermValidationCode] = 'UNKNOWN_TERM' OR a.[TermValidationCode] = 'CLOSED_TERM'
                        THEN 1 ELSE 0 END AS BIT),
                    a.[TermValidationCode]),
                ('DUPLICATE_APPLICATION',
                    CAST(CASE WHEN a.[DuplicateApplicationCount] > 1 THEN 1 ELSE 0 END AS BIT),
                    CONCAT('GROUP_SIZE:', a.[DuplicateApplicationCount])),
                ('INVALID_CONTACT_FORMAT',
                    CAST(CASE WHEN a.[IsEmailValid] = 0 OR a.[IsPhoneValid] = 0 THEN 1 ELSE 0 END AS BIT),
                    CONCAT_WS(',', CASE WHEN a.[IsEmailValid] = 0 THEN 'EMAIL' END, CASE WHEN a.[IsPhoneValid] = 0 THEN 'PHONE' END))
        ) AS c ([ExceptionReasonCode], [IsPresent], [DetailCode])
        WHERE a.[IsEligible] = 1
          AND NOT EXISTS (SELECT 1 FROM [integration].[vw_IntegratedApplication] AS ia WHERE ia.[ApplicationId] = a.[ApplicationId]);

        INSERT INTO @Transitions ([ExceptionId], [ToStatusCode])
        SELECT e.[ExceptionId], 'CLOSED' AS [ToStatusCode]
        FROM [integration].[IntegrationException] AS e
        INNER JOIN [staging].[Applicant] AS a ON e.[ApplicationId] = a.[ApplicationId]
        WHERE a.[IsEligible] = 0
          AND e.[ExceptionStatusCode] <> 'REPROCESSED'
          AND e.[ExceptionStatusCode] <> 'CLOSED';

        BEGIN TRANSACTION;

        EXEC [integration].[usp_RecordExceptionConditions]
            @BatchId = @BatchId, @Conditions = @Conditions, @RaisedBy = N'integration.usp_RaiseValidationExceptions';

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Transitions,
            @ReasonText = N'The application is no longer eligible for integration.',
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
