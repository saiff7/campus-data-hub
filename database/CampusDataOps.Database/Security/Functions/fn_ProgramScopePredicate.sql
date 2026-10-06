-- Row-level security predicate for program coordinators (docs/architecture/security-model.md).
-- A row is visible unless the caller is a member of role_program_coordinator without scope for
-- the row's program. Members of any other role are not filtered: their grants decide what they
-- may read.
CREATE FUNCTION [security].[fn_ProgramScopePredicate] (@ProgramCode VARCHAR (20))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT 1 AS [IsVisible]
WHERE ISNULL(IS_ROLEMEMBER(N'role_program_coordinator'), 0) = 0
   OR EXISTS (
       SELECT 1
       FROM [security].[UserProgramScope] AS s
       WHERE s.[UserName] = USER_NAME()
         AND s.[ProgramCode] = @ProgramCode
   );
