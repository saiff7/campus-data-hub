-- Grants or removes one program from a coordinator's row-level security scope
-- (docs/architecture/security-model.md). Requires role_security_admin (or db_owner); audited.
CREATE PROCEDURE [security].[usp_SetProgramScope]
    @UserName        NVARCHAR (128),
    @ProgramCode     VARCHAR (20),
    @IsGranted       BIT,
    @TicketReference NVARCHAR (50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ObjectName NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @Subject VARCHAR (100) = LEFT(CONCAT(@ProgramCode, ':', @UserName), 100);
    DECLARE @Refusal NVARCHAR (400) = CASE
        WHEN NOT (IS_MEMBER(N'role_security_admin') = 1 OR IS_MEMBER(N'db_owner') = 1)
            THEN N'Changing program scope requires role_security_admin.'
        WHEN NULLIF(LTRIM(RTRIM(@TicketReference)), N'') IS NULL THEN N'An access-request ticket reference is required.'
        WHEN @IsGranted IS NULL THEN N'@IsGranted must be 1 or 0.'
        WHEN NOT EXISTS (SELECT 1 FROM [reference].[AcademicProgram] AS p WHERE p.[ProgramCode] = @ProgramCode)
            THEN N'Unknown program.'
    END;

    IF @Refusal IS NOT NULL
    BEGIN
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = 'PROGRAM_SCOPE_CHANGE', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 0,
            @SubjectKey = @Subject, @Detail = @Refusal;
        THROW 52303, @Refusal, 1;
    END;

    IF @IsGranted = 1
        INSERT INTO [security].[UserProgramScope] ([UserName], [ProgramCode])
        SELECT @UserName AS [UserName], @ProgramCode AS [ProgramCode]
        WHERE NOT EXISTS (
            SELECT 1 FROM [security].[UserProgramScope] AS s WHERE s.[UserName] = @UserName AND s.[ProgramCode] = @ProgramCode
        );
    ELSE
        DELETE s
        FROM [security].[UserProgramScope] AS s
        WHERE s.[UserName] = @UserName AND s.[ProgramCode] = @ProgramCode;

    EXEC [audit].[usp_LogAccessEvent]
        @EventType = 'PROGRAM_SCOPE_CHANGE', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 1, @SubjectKey = @Subject,
        @Detail = @TicketReference;
END;
