-- Records one audit.AccessEvent for the calling user. Callers log before acting, and log refusals
-- before raising them, so an attempt is never lost.
CREATE PROCEDURE [audit].[usp_LogAccessEvent]
    @EventType    VARCHAR (30),
    @ObjectName   NVARCHAR (256),
    @IsPrivileged BIT,
    @IsAllowed    BIT,
    @ExtractRunId BIGINT         = NULL,
    @SubjectKey   VARCHAR (100)  = NULL,
    @Detail       NVARCHAR (400) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [audit].[AccessEvent] (
        [EventType], [ObjectName], [IsPrivileged], [IsAllowed], [ExtractRunId], [SubjectKey], [Detail]
    )
    VALUES (@EventType, @ObjectName, @IsPrivileged, @IsAllowed, @ExtractRunId, @SubjectKey, @Detail);
END;
