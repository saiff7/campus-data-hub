-- The NOTIFY step: returns the run summary operators read in the job history and fails when
-- the run is not balanced, so an unexplained difference can never end in a SUCCEEDED run.
-- (Email delivery through Database Mail is configured with the Part 3 alerts.)
CREATE PROCEDURE [integration].[usp_PublishRunSummary]
    @BatchId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IsBalanced BIT;
    DECLARE @Message NVARCHAR (400);

    SET @IsBalanced = (SELECT rr.[IsBalanced] FROM [integration].[ReconciliationResult] AS rr WHERE rr.[BatchId] = @BatchId);

    SELECT
        rr.[BatchId],
        rr.[SourceEligible],
        rr.[Unchanged],
        rr.[Matched],
        rr.[Created],
        rr.[Rejected],
        rr.[Pending],
        rr.[Processed],
        rr.[TargetConfirmed],
        rr.[EntityMismatchCount],
        rr.[IsBalanced],
        openex.[OpenExceptionCount],
        openex.[OpenBlockingExceptionCount]
    FROM [integration].[ReconciliationResult] AS rr
    CROSS APPLY (
        SELECT
            COUNT(*) AS [OpenExceptionCount],
            SUM(CASE WHEN w.[BlocksProcessing] = 1 THEN 1 ELSE 0 END) AS [OpenBlockingExceptionCount]
        FROM [integration].[vw_OpenExceptionWorklist] AS w
    ) AS openex
    WHERE rr.[BatchId] = @BatchId;

    IF @IsBalanced IS NULL
    BEGIN
        SET @Message = CONCAT(N'Batch ', @BatchId, N' has no reconciliation result; run the RECONCILE step first.');
        THROW 50400, @Message, 1;
    END;

    IF @IsBalanced = 0
    BEGIN
        SET @Message = CONCAT(
            N'Batch ', @BatchId, N' did not reconcile; see integration.ReconciliationResult and the ',
            N'RECONCILIATION_COUNT_MISMATCH exception for this batch.'
        );
        THROW 50401, @Message, 1;
    END;
END;
