-- R5 drill-through: the full applicant values behind one exception and its candidate SIS
-- records. Every call is audited in audit.AccessEvent, including refused ones; an access
-- reason is required. Returns two result sets: applicant, then candidates.
CREATE PROCEDURE [reporting].[usp_GetExceptionDetail]
    @ExceptionId  BIGINT,
    @AccessReason NVARCHAR (200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ObjectName NVARCHAR (256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @SubjectKey VARCHAR (100) = CONVERT(VARCHAR (100), @ExceptionId);
    DECLARE @ApplicationId UNIQUEIDENTIFIER;

    IF NULLIF(LTRIM(RTRIM(@AccessReason)), N'') IS NULL
    BEGIN
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = 'EXCEPTION_DRILLTHROUGH', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 0,
            @SubjectKey = @SubjectKey, @Detail = N'REFUSED: no access reason';
        THROW 52204, N'An access reason is required to view applicant detail.', 1;
    END;

    SET @ApplicationId = (SELECT e.[ApplicationId] FROM [integration].[IntegrationException] AS e WHERE e.[ExceptionId] = @ExceptionId);
    IF @ApplicationId IS NULL
    BEGIN
        EXEC [audit].[usp_LogAccessEvent]
            @EventType = 'EXCEPTION_DRILLTHROUGH', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 0,
            @SubjectKey = @SubjectKey, @Detail = N'REFUSED: unknown exception or no application';
        THROW 52205, N'Unknown exception, or the exception is not about an application.', 1;
    END;

    EXEC [audit].[usp_LogAccessEvent]
        @EventType = 'EXCEPTION_DRILLTHROUGH', @ObjectName = @ObjectName, @IsPrivileged = 1, @IsAllowed = 1,
        @SubjectKey = @SubjectKey, @Detail = @AccessReason;

    SELECT
        e.[ExceptionId], e.[ExceptionReasonCode], e.[ExceptionStatusCode], e.[DetailCode], a.[ApplicationId], a.[SlatePersonId],
        a.[ApplicationStatus], a.[FirstNameRaw], a.[FirstNameStd], a.[LastNameRaw], a.[LastNameStd], a.[BirthDate], a.[EmailRaw],
        a.[EmailStd], a.[PhoneRaw], a.[PhoneStd], a.[PostalCode5], a.[SisIdClaim], a.[EntryTermCodeRaw], a.[ProgramChoice1Raw]
    FROM [integration].[IntegrationException] AS e
    INNER JOIN [core].[vw_Application] AS a ON e.[ApplicationId] = a.[ApplicationId]
    WHERE e.[ExceptionId] = @ExceptionId;

    SELECT
        mc.[CandidateIdNumber], mc.[RuleCode], mc.[MatchedOnSisId], mc.[MatchedOnEmail], mc.[MatchedOnBirthDate],
        mc.[MatchedOnName], mc.[MatchedOnPostalCode], p.[FirstNameStd], p.[LastNameStd], p.[BirthDate]
    FROM [integration].[MatchDecision] AS d
    INNER JOIN [integration].[MatchCandidate] AS mc ON d.[MatchEvaluationId] = mc.[MatchEvaluationId]
    LEFT JOIN [core].[vw_Person] AS p ON mc.[CandidateIdNumber] = p.[IdNumber]
    WHERE d.[ApplicationId] = @ApplicationId
      AND d.[IsCurrent] = 1
    ORDER BY mc.[CandidateIdNumber], mc.[RuleCode];
END;
