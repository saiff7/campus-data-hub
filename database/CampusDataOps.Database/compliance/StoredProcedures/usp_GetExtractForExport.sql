-- The only way to read an extract's lines (docs/specifications/extract-controls.md). Checks the
-- caller against the type's access role, audits the export (refusals too), and returns three
-- result sets: the run (one row), its control totals, then its lines in order.
CREATE PROCEDURE [compliance].[usp_GetExtractForExport]
    @ExtractRunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ObjectName NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @AccessRoleName NVARCHAR (128);
    DECLARE @IsPrivileged BIT;
    DECLARE @StatusCode VARCHAR (15);

    SELECT @AccessRoleName = t.[AccessRoleName], @IsPrivileged = t.[IsPrivileged], @StatusCode = r.[ExtractStatusCode]
    FROM [compliance].[ExtractRun] AS r
    INNER JOIN [reference].[ExtractType] AS t ON r.[ExtractTypeCode] = t.[ExtractTypeCode]
    WHERE r.[ExtractRunId] = @ExtractRunId;

    IF @StatusCode IS NULL OR @StatusCode <> 'SUCCEEDED'
    BEGIN
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = 'EXTRACT_EXPORT', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 0, @ExtractRunId = @ExtractRunId,
            @Detail = N'REFUSED: no successful run with this id';
        THROW 52116, N'Only a successful extract run can be exported.', 1;
    END;

    IF NOT (IS_MEMBER(@AccessRoleName) = 1 OR IS_MEMBER(N'role_integration_service') = 1 OR IS_MEMBER(N'db_owner') = 1)
    BEGIN
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = 'EXTRACT_EXPORT', @ObjectName = @ObjectName, @IsPrivileged = @IsPrivileged, @IsAllowed = 0,
            @ExtractRunId = @ExtractRunId, @Detail = N'REFUSED: caller is not in the extract type''s access role';
        THROW 52117, N'Exporting this extract requires membership of its access role.', 1;
    END;

    EXEC [audit].[usp_LogAccessEvent]
        @EventType = 'EXTRACT_EXPORT', @ObjectName = @ObjectName, @IsPrivileged = @IsPrivileged, @IsAllowed = 1,
        @ExtractRunId = @ExtractRunId;

    SELECT
        r.[ExtractRunId], r.[ExtractTypeCode], r.[ReportingPeriod], r.[SourceBatchId], r.[CensusSnapshotId], r.[GeneratorVersion],
        r.[GeneratedAtUtc], r.[CompletedAtUtc], r.[LineCount], r.[DataRowCount], r.[ValidationStatusCode], r.[ApprovalStatusCode],
        r.[ApprovedBy], r.[ApprovedAtUtc], t.[Description], t.[SecurityClass], t.[IsPublicSafe],
        LOWER(CONVERT(CHAR (64), r.[ContentSha256], 2)) AS [ContentSha256]
    FROM [compliance].[ExtractRun] AS r
    INNER JOIN [reference].[ExtractType] AS t ON r.[ExtractTypeCode] = t.[ExtractTypeCode]
    WHERE r.[ExtractRunId] = @ExtractRunId;

    SELECT
        c.[ControlCode], c.[ControlKind], c.[ComparisonOperator], c.[ExpectedValue], c.[ActualValue], c.[PriorExtractRunId],
        c.[PriorValue], c.[ChangePct], c.[ThresholdPct], c.[OutcomeCode], c.[Note]
    FROM [compliance].[ExtractControlTotal] AS c
    WHERE c.[ExtractRunId] = @ExtractRunId
    ORDER BY c.[ControlCode];

    SELECT r.[LineNumber], r.[LineText]
    FROM [compliance].[ExtractRow] AS r
    WHERE r.[ExtractRunId] = @ExtractRunId
    ORDER BY r.[LineNumber];
END;
