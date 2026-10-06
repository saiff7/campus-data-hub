-- Records every database security event in audit.PermissionChangeEvent. It runs as dbo so the
-- caller needs no right on the audit table; EVENTDATA() keeps the caller's own login and user.
CREATE TRIGGER [trg_audit_PermissionChange]
ON DATABASE
WITH EXECUTE AS 'dbo'
FOR DDL_DATABASE_SECURITY_EVENTS
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Event XML = EVENTDATA();

    INSERT INTO [audit].[PermissionChangeEvent] (
        [EventType], [LoginName], [UserName], [ObjectName], [Permissions], [Grantees], [CommandText]
    )
    SELECT
        @Event.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(64)') AS [EventType],
        @Event.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)') AS [LoginName],
        @Event.value('(/EVENT_INSTANCE/UserName)[1]', 'NVARCHAR(128)') AS [UserName],
        CONCAT_WS(
            N'.', @Event.value('(/EVENT_INSTANCE/SchemaName)[1]', 'NVARCHAR(128)'),
            @Event.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)')
        ) AS [ObjectName],
        LEFT(@Event.value('(/EVENT_INSTANCE/Permissions)[1]', 'NVARCHAR(MAX)'), 400) AS [Permissions],
        LEFT(@Event.value('(/EVENT_INSTANCE/Grantees)[1]', 'NVARCHAR(MAX)'), 400) AS [Grantees],
        LEFT(@Event.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'), 2000) AS [CommandText];
END;
