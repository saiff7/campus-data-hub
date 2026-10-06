-- Records the approval decision on a successful extract run (docs/specifications/extract-controls.md).
-- Requires role_ir_analyst (or db_owner); the approver must not be the requester and a run that
-- failed validation cannot be approved, which CHECK constraints also enforce. A decision is final.
-- Every attempt is audited.
CREATE PROCEDURE [compliance].[usp_ApproveExtract]
    @ExtractRunId BIGINT,
    @Decision     VARCHAR (10)   = 'APPROVED',
    @Note         NVARCHAR (400) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ObjectName NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @EventType VARCHAR (30) = CASE WHEN @Decision = 'REJECTED' THEN 'EXTRACT_REJECT' ELSE 'EXTRACT_APPROVE' END;
    DECLARE @Refusal NVARCHAR (400);
    DECLARE @ErrorNumber INT;
    DECLARE @StatusCode VARCHAR (15);
    DECLARE @ValidationCode VARCHAR (15);
    DECLARE @ApprovalCode VARCHAR (15);
    DECLARE @RequestedBy NVARCHAR (128);

    SELECT
        @StatusCode = r.[ExtractStatusCode], @ValidationCode = r.[ValidationStatusCode], @ApprovalCode = r.[ApprovalStatusCode],
        @RequestedBy = r.[RequestedBy]
    FROM [compliance].[ExtractRun] AS r
    WHERE r.[ExtractRunId] = @ExtractRunId;

    SELECT @ErrorNumber = x.[ErrorNumber], @Refusal = x.[Refusal]
    FROM (
        SELECT TOP (1) v.[ErrorNumber], v.[Refusal]
        FROM (
            VALUES
                (1, 52110, CASE WHEN NOT (IS_MEMBER(N'role_ir_analyst') = 1 OR IS_MEMBER(N'db_owner') = 1)
                    THEN N'Approving extracts requires role_ir_analyst.' END),
                (2, 52112, CASE WHEN @Decision IS NULL OR NOT (@Decision = 'APPROVED' OR @Decision = 'REJECTED')
                    THEN N'The decision must be APPROVED or REJECTED.' END),
                (3, 52111, CASE WHEN @StatusCode IS NULL OR @StatusCode <> 'SUCCEEDED'
                    THEN N'Only a successful extract run can be reviewed.' END),
                (4, 52115, CASE WHEN @ApprovalCode <> 'PENDING' THEN N'This run already has a decision.' END),
                (5, 52114, CASE WHEN @RequestedBy = USER_NAME() THEN N'The requester of a run cannot review it.' END),
                (6, 52113, CASE WHEN @Decision = 'APPROVED' AND @ValidationCode = 'FAILED'
                    THEN N'A run that failed validation cannot be approved.' END)
        ) AS v ([CheckOrder], [ErrorNumber], [Refusal])
        WHERE v.[Refusal] IS NOT NULL
        ORDER BY v.[CheckOrder]
    ) AS x;

    IF @Refusal IS NOT NULL
    BEGIN
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = @EventType, @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 0, @ExtractRunId = @ExtractRunId,
            @Detail = @Refusal;
        THROW @ErrorNumber, @Refusal, 1;
    END;

    UPDATE r
    SET r.[ApprovalStatusCode] = @Decision,
        r.[ApprovedBy] = USER_NAME(),
        r.[ApprovedAtUtc] = SYSUTCDATETIME(),
        r.[ApprovalNote] = @Note
    FROM [compliance].[ExtractRun] AS r
    WHERE r.[ExtractRunId] = @ExtractRunId;

    EXEC [audit].[usp_LogAccessEvent]
        @EventType = @EventType, @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 1, @ExtractRunId = @ExtractRunId,
        @Detail = @Note;
END;
