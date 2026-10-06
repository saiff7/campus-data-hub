-- R4 for one term.
CREATE PROCEDURE [reporting].[usp_ReportAcademicOutcomes]
    @TermCode VARCHAR (10)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [reference].[AcademicTerm] AS t WHERE t.[TermCode] = @TermCode)
        THROW 52203, N'Unknown term.', 1;

    SELECT
        a.[IdNumber], a.[TermCode], a.[ProgramCode], a.[AttemptedCredits], a.[EarnedCredits], a.[GpaCredits],
        a.[QualityPoints], a.[TermGpa], a.[CumulativeAttemptedCredits], a.[CumulativeEarnedCredits], a.[CumulativeGpaCredits],
        a.[CumulativeGpa], a.[AcademicStanding], a.[GradesPending], a.[RequiredCredits], a.[IsCompletionEligible],
        a.[HasCredential]
    FROM [reporting].[vw_AcademicProgress] AS a
    WHERE a.[TermCode] = @TermCode
    ORDER BY a.[IdNumber];
END;
