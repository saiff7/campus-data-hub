-- SIS_DUPLICATE_PERSON: J1-Sim people who share normalized first and last name, birth date and
-- five-digit postal code (the same values matching rule 4 uses). DetailCode GROUP:<lowest
-- IdNumber> ties the members of a group together.
CREATE PROCEDURE [dq].[usp_CheckDuplicatePeople]
    @ValidationRunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Evaluations [dq].[RuleEvaluation];
    DECLARE @CheckProcedure NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));

    WITH [Grouped] AS (
        SELECT
            p.[IdNumber],
            p.[PostalCode5],
            COUNT(*) OVER (PARTITION BY p.[LastNameStd], p.[FirstNameStd], p.[BirthDate], p.[PostalCode5]) AS [GroupSize],
            MIN(p.[IdNumber]) OVER (PARTITION BY p.[LastNameStd], p.[FirstNameStd], p.[BirthDate], p.[PostalCode5]) AS [GroupId]
        FROM [staging].[Person] AS p
    )

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'SIS_DUPLICATE_PERSON' AS [RuleCode],
        CAST(g.[IdNumber] AS VARCHAR (12)) AS [RecordKey],
        CAST(CASE WHEN g.[PostalCode5] IS NOT NULL AND g.[GroupSize] > 1 THEN 1 ELSE 0 END AS BIT) AS [IsFailure],
        CASE WHEN g.[PostalCode5] IS NOT NULL AND g.[GroupSize] > 1 THEN CONCAT('GROUP:', g.[GroupId]) END AS [DetailCode]
    FROM [Grouped] AS g;

    EXEC [dq].[usp_RecordRuleEvaluations]
        @ValidationRunId = @ValidationRunId, @CheckProcedure = @CheckProcedure, @Evaluations = @Evaluations;
END;
