-- Gives every staged student without one a surrogate key, in random order. Idempotent; called
-- by the STAGE pipeline step.
CREATE PROCEDURE [security].[usp_AssignStudentPseudonyms]
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [security].[StudentPseudonym] ([IdNumber])
    SELECT p.[IdNumber]
    FROM [staging].[Person] AS p
    WHERE p.[HasStudentRecord] = 1
      AND NOT EXISTS (SELECT 1 FROM [security].[StudentPseudonym] AS sp WHERE sp.[IdNumber] = p.[IdNumber])
    ORDER BY NEWID();

    SET @RowsAffected = @@ROWCOUNT;
END;
