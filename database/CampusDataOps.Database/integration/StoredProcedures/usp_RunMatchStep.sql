-- The MATCH pipeline step as one atomic unit: validation exceptions, candidates, decisions and
-- identity exceptions either all commit or none do. Returns the number of decisions written.
CREATE PROCEDURE [integration].[usp_RunMatchStep]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC [integration].[usp_RaiseValidationExceptions] @BatchId = @BatchId;
        EXEC [integration].[usp_BuildApplicantMatchCandidates] @BatchId = @BatchId;
        EXEC [integration].[usp_ResolveDeterministicMatches] @BatchId = @BatchId, @RowsAffected = @RowsAffected OUTPUT;
        EXEC [integration].[usp_RaiseIdentityExceptions] @BatchId = @BatchId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
