-- Stages the latest landed version of each J1-Sim enrollment. Values are already typed by the
-- SIS; integrity is checked by dq.usp_CheckEnrollmentIntegrity rather than corrected here.
CREATE PROCEDURE [staging].[usp_StageJ1Enrollments]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

    BEGIN TRY
        WITH [Latest] AS (
            SELECT
                r.[LandingRowId], r.[EnrollmentId], r.[IdNumber], r.[CourseSectionId], r.[TermCode], r.[SubjectCode],
                r.[CourseNumber], r.[SectionNumber], r.[CreditHours], r.[RegistrationStatus], r.[RegisteredAtUtc],
                r.[StatusChangedAtUtc], r.[GradeCode], r.[GradePoints], r.[GradePostedAtUtc],
                ROW_NUMBER() OVER (PARTITION BY r.[EnrollmentId] ORDER BY r.[BatchId] DESC) AS [VersionRank]
            FROM [landing].[J1EnrollmentRaw] AS r
        )

        SELECT
            l.[LandingRowId], l.[EnrollmentId], l.[IdNumber], l.[CourseSectionId], l.[TermCode], l.[SubjectCode],
            l.[CourseNumber], l.[SectionNumber], l.[CreditHours], l.[RegistrationStatus], l.[RegisteredAtUtc],
            l.[StatusChangedAtUtc], l.[GradeCode], l.[GradePoints], l.[GradePostedAtUtc]
        INTO #Staged
        FROM [Latest] AS l
        WHERE l.[VersionRank] = 1
          AND NOT EXISTS (
              SELECT 1
              FROM [staging].[Enrollment] AS e
              WHERE e.[EnrollmentId] = l.[EnrollmentId] AND e.[LandingRowId] = l.[LandingRowId]
          );

        BEGIN TRANSACTION;

        UPDATE e
        SET e.[LandingRowId] = st.[LandingRowId],
            e.[IdNumber] = st.[IdNumber],
            e.[CourseSectionId] = st.[CourseSectionId],
            e.[TermCode] = st.[TermCode],
            e.[SubjectCode] = st.[SubjectCode],
            e.[CourseNumber] = st.[CourseNumber],
            e.[SectionNumber] = st.[SectionNumber],
            e.[CreditHours] = st.[CreditHours],
            e.[RegistrationStatus] = st.[RegistrationStatus],
            e.[RegisteredAtUtc] = st.[RegisteredAtUtc],
            e.[StatusChangedAtUtc] = st.[StatusChangedAtUtc],
            e.[GradeCode] = st.[GradeCode],
            e.[GradePoints] = st.[GradePoints],
            e.[GradePostedAtUtc] = st.[GradePostedAtUtc],
            e.[LastStagedBatchId] = @BatchId,
            e.[UpdatedAtUtc] = @NowUtc
        FROM [staging].[Enrollment] AS e
        INNER JOIN #Staged AS st ON e.[EnrollmentId] = st.[EnrollmentId];

        SET @RowsAffected = @@ROWCOUNT;

        INSERT INTO [staging].[Enrollment] (
            [EnrollmentId], [LandingRowId], [IdNumber], [CourseSectionId], [TermCode], [SubjectCode], [CourseNumber],
            [SectionNumber], [CreditHours], [RegistrationStatus], [RegisteredAtUtc], [StatusChangedAtUtc],
            [GradeCode], [GradePoints], [GradePostedAtUtc], [LastStagedBatchId]
        )
        SELECT
            st.[EnrollmentId], st.[LandingRowId], st.[IdNumber], st.[CourseSectionId], st.[TermCode], st.[SubjectCode],
            st.[CourseNumber], st.[SectionNumber], st.[CreditHours], st.[RegistrationStatus], st.[RegisteredAtUtc],
            st.[StatusChangedAtUtc], st.[GradeCode], st.[GradePoints], st.[GradePostedAtUtc],
            @BatchId AS [LastStagedBatchId]
        FROM #Staged AS st
        WHERE NOT EXISTS (SELECT 1 FROM [staging].[Enrollment] AS e WHERE e.[EnrollmentId] = st.[EnrollmentId]);

        SET @RowsAffected += @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
