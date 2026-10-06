-- Cross-system rules: active students have an enabled student directory account, student
-- directory accounts belong to a J1-Sim person, and every application written to J1-Sim has a
-- source crosswalk.
CREATE PROCEDURE [dq].[usp_CheckCrossSystemConsistency]
    @ValidationRunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Evaluations [dq].[RuleEvaluation];
    DECLARE @CheckProcedure NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'DIR_ACTIVE_STUDENT_ACCOUNT' AS [RuleCode],
        CAST(p.[IdNumber] AS VARCHAR (12)) AS [RecordKey],
        CAST(CASE WHEN acct.[AccountGuid] IS NULL THEN 1 ELSE 0 END AS BIT) AS [IsFailure],
        CASE WHEN acct.[AccountGuid] IS NULL THEN 'NO_ENABLED_STUDENT_ACCOUNT' END AS [DetailCode]
    FROM [staging].[Person] AS p
    OUTER APPLY (
        SELECT TOP (1) d.[AccountGuid]
        FROM [staging].[DirectoryAccount] AS d
        WHERE d.[EmployeeIdNumber] = p.[IdNumber]
          AND d.[AccountType] = 'STUDENT'
          AND d.[IsEnabled] = 1
    ) AS acct
    WHERE p.[StudentStatus] = 'ACTIVE';

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'DIR_ORPHAN_ACCOUNT' AS [RuleCode],
        CAST(d.[AccountGuid] AS VARCHAR (36)) AS [RecordKey],
        CAST(CASE WHEN p.[IdNumber] IS NULL THEN 1 ELSE 0 END AS BIT) AS [IsFailure],
        CASE
            WHEN d.[EmployeeIdNumber] IS NULL THEN 'MISSING_OR_NON_NUMERIC_EMPLOYEE_ID'
            WHEN p.[IdNumber] IS NULL THEN 'NOT_A_J1_PERSON'
        END AS [DetailCode]
    FROM [staging].[DirectoryAccount] AS d
    LEFT JOIN [staging].[Person] AS p ON d.[EmployeeIdNumber] = p.[IdNumber]
    WHERE d.[AccountType] = 'STUDENT';

    INSERT INTO @Evaluations ([RuleCode], [RecordKey], [IsFailure], [DetailCode])
    SELECT
        'INT_CROSSWALK_PRESENT' AS [RuleCode],
        CAST(q.[ApplicationId] AS VARCHAR (36)) AS [RecordKey],
        CAST(CASE WHEN c.[SourceCrosswalkId] IS NULL THEN 1 ELSE 0 END AS BIT) AS [IsFailure],
        CASE WHEN c.[SourceCrosswalkId] IS NULL THEN 'NO_CROSSWALK' END AS [DetailCode]
    FROM [integration].[OutboundStudentQueue] AS q
    LEFT JOIN [integration].[SourceCrosswalk] AS c
        ON c.[SourceSystemCode] = 'SLATE_SIM'
       AND c.[SourceRecordId] = CAST(q.[SlatePersonId] AS VARCHAR (64))
    WHERE q.[QueueStatusCode] = 'SUCCEEDED';

    EXEC [dq].[usp_RecordRuleEvaluations]
        @ValidationRunId = @ValidationRunId, @CheckProcedure = @CheckProcedure, @Evaluations = @Evaluations;
END;
