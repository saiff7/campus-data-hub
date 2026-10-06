-- Applicant rules (docs/specifications/data-quality-rules.md): required fields, email and phone
-- format, program and term validity, duplicate applications. Required-field, program, term and
-- duplicate rules evaluate eligible applications; format rules evaluate every application with
-- a value present.
CREATE PROCEDURE [dq].[usp_CheckApplicantRules]
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
        CAST(a.[ApplicationId] AS VARCHAR (36)) AS [RecordKey],
        r.[IsFailure],
        CASE WHEN r.[IsFailure] = 1 THEN r.[DetailCode] END AS [DetailCode]
    FROM [staging].[Applicant] AS a
    CROSS APPLY (
        VALUES
            ('APP_REQUIRED_FIELDS', a.[IsEligible],
                CAST(CASE WHEN a.[MissingRequiredFields] IS NOT NULL THEN 1 ELSE 0 END AS BIT), a.[MissingRequiredFields]),
            ('APP_EMAIL_FORMAT', CAST(CASE WHEN a.[IsEmailValid] IS NOT NULL THEN 1 ELSE 0 END AS BIT),
                CAST(CASE WHEN a.[IsEmailValid] = 0 THEN 1 ELSE 0 END AS BIT), 'INVALID_EMAIL'),
            ('APP_PHONE_FORMAT', CAST(CASE WHEN a.[IsPhoneValid] IS NOT NULL THEN 1 ELSE 0 END AS BIT),
                CAST(CASE WHEN a.[IsPhoneValid] = 0 THEN 1 ELSE 0 END AS BIT), 'INVALID_PHONE'),
            ('APP_PROGRAM_VALID', a.[IsEligible],
                CAST(CASE WHEN a.[ProgramValidationCode] = 'NOT_IN_CROSSWALK' OR a.[ProgramValidationCode] = 'INACTIVE'
                    THEN 1 ELSE 0 END AS BIT),
                a.[ProgramValidationCode]),
            ('APP_TERM_VALID', a.[IsEligible],
                CAST(CASE WHEN a.[TermValidationCode] = 'UNKNOWN_TERM' OR a.[TermValidationCode] = 'CLOSED_TERM'
                    THEN 1 ELSE 0 END AS BIT),
                a.[TermValidationCode]),
            ('APP_DUPLICATE_APPLICATION', a.[IsEligible],
                CAST(CASE WHEN a.[DuplicateApplicationCount] > 1 THEN 1 ELSE 0 END AS BIT),
                CONCAT('GROUP_SIZE:', a.[DuplicateApplicationCount]))
    ) AS r ([RuleCode], [IsEvaluated], [IsFailure], [DetailCode])
    WHERE r.[IsEvaluated] = 1;

    EXEC [dq].[usp_RecordRuleEvaluations]
        @ValidationRunId = @ValidationRunId, @CheckProcedure = @CheckProcedure, @Evaluations = @Evaluations;
END;
