-- Records the owner's decision on one rule failure, superseding the current one
-- (docs/specifications/data-quality-rules.md). A note is required; an accepted exception needs a
-- review date.
CREATE PROCEDURE [dq].[usp_RecordIssueDisposition]
    @RuleCode        VARCHAR (40),
    @RecordKey       VARCHAR (100),
    @DispositionCode VARCHAR (20),
    @Note            NVARCHAR (400),
    @ReviewBy        DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

    IF NULLIF(LTRIM(RTRIM(@Note)), N'') IS NULL
        THROW 52401, N'A disposition needs a note explaining the decision.', 1;
    IF NOT EXISTS (SELECT 1 FROM [dq].[RuleResult] AS r WHERE r.[RuleCode] = @RuleCode AND r.[RecordKey] = @RecordKey)
        THROW 52402, N'No data-quality failure has been recorded for this rule and record.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE d
        SET d.[IsCurrent] = 0, d.[SupersededAtUtc] = @NowUtc
        FROM [dq].[IssueDisposition] AS d
        WHERE d.[RuleCode] = @RuleCode AND d.[RecordKey] = @RecordKey AND d.[IsCurrent] = 1;

        INSERT INTO [dq].[IssueDisposition] ([RuleCode], [RecordKey], [DispositionCode], [Note], [ReviewBy], [IsCurrent])
        VALUES (@RuleCode, @RecordKey, @DispositionCode, @Note, @ReviewBy, 1);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
