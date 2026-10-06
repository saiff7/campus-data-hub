-- Adds a database user to a managed role for an approved access request
-- (docs/runbooks/access-request.md). Requires role_security_admin (or db_owner); the caller's own
-- ALTER permission on the role does the change, so no privilege is borrowed. Only roles listed
-- in security.ManagedRole are accepted. Audited in audit.AccessEvent, and the membership change
-- itself in audit.PermissionChangeEvent.
CREATE PROCEDURE [security].[usp_GrantRoleMembership]
    @UserName        NVARCHAR (128),
    @RoleName        NVARCHAR (128),
    @TicketReference NVARCHAR (50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ObjectName NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @Subject VARCHAR (100) = LEFT(CONCAT(@RoleName, ':', @UserName), 100);
    DECLARE @Refusal NVARCHAR (400) = CASE
        WHEN NOT (IS_MEMBER(N'role_security_admin') = 1 OR IS_MEMBER(N'db_owner') = 1)
            THEN N'Granting role membership requires role_security_admin.'
        WHEN NULLIF(LTRIM(RTRIM(@TicketReference)), N'') IS NULL THEN N'An access-request ticket reference is required.'
        WHEN NOT EXISTS (SELECT 1 FROM [security].[ManagedRole] AS m WHERE m.[RoleName] = @RoleName)
            THEN N'The role is not a managed role.'
    END;
    DECLARE @Sql NVARCHAR (400);

    IF @Refusal IS NOT NULL
    BEGIN
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = 'ROLE_GRANT', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 0, @SubjectKey = @Subject,
            @Detail = @Refusal;
        THROW 52301, @Refusal, 1;
    END;

    -- No existence pre-check: metadata visibility hides other users from a security admin, so
    -- ALTER ROLE itself reports a missing user, and the failure is audited before it is raised.
    SET @Sql = CONCAT(N'ALTER ROLE ', QUOTENAME(@RoleName), N' ADD MEMBER ', QUOTENAME(@UserName), N';');
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        SET @Refusal = LEFT(CONCAT(N'FAILED: ', ERROR_MESSAGE()), 400);
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = 'ROLE_GRANT', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 0, @SubjectKey = @Subject,
            @Detail = @Refusal;
        THROW;
    END CATCH;

    EXEC [audit].[usp_LogAccessEvent]
        @EventType = 'ROLE_GRANT', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 1, @SubjectKey = @Subject,
        @Detail = @TicketReference;
END;
