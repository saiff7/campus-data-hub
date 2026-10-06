-- Enrollment rules: the person has a student record, the term is governed, and the grade
-- agrees with the registration status. J1-Sim enforces some of this with foreign keys, but
-- landed data can drift between incremental loads, so CampusDataOps checks it independently.
CREATE PROCEDURE [dq].[usp_CheckEnrollmentIntegrity]
    @ValidationRunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Evaluations [dq].[RuleEvaluation];
    DECLARE @CheckProcedure NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        r.[RuleCode],
        CAST(e.[EnrollmentId] AS VARCHAR (20)) AS [RecordKey],
        r.[IsFailure],
        CASE WHEN r.[IsFailure] = 1 THEN r.[DetailCode] END AS [DetailCode]
    FROM [staging].[Enrollment] AS e
    LEFT JOIN [staging].[Person] AS p
        ON e.[IdNumber] = p.[IdNumber]
       AND p.[HasStudentRecord] = 1
    LEFT JOIN [reference].[AcademicTerm] AS t ON e.[TermCode] = t.[TermCode]
    CROSS APPLY (
        VALUES
            ('ENR_STUDENT_EXISTS', CAST(CASE WHEN p.[IdNumber] IS NULL THEN 1 ELSE 0 END AS BIT), 'NO_STUDENT_RECORD'),
            ('ENR_TERM_VALID', CAST(CASE WHEN t.[TermCode] IS NULL THEN 1 ELSE 0 END AS BIT), 'UNKNOWN_TERM'),
            ('ENR_GRADE_STATUS',
                CAST(CASE
                    WHEN e.[RegistrationStatus] = 'DROPPED' AND e.[GradeCode] IS NOT NULL THEN 1
                    WHEN e.[RegistrationStatus] = 'WITHDRAWN' AND e.[GradeCode] IS NOT NULL AND e.[GradeCode] <> 'W' THEN 1
                    ELSE 0
                END AS BIT),
                CONCAT(e.[RegistrationStatus], '_WITH_GRADE'))
    ) AS r ([RuleCode], [IsFailure], [DetailCode]);

    EXEC [dq].[usp_RecordRuleEvaluations]
        @ValidationRunId = @ValidationRunId, @CheckProcedure = @CheckProcedure, @Evaluations = @Evaluations;
END;
