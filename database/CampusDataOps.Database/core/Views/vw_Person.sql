-- Conformed SIS people with their standardized identity values. Protected: no managed role
-- may read core directly; reporting objects expose only what each report needs.
CREATE VIEW [core].[vw_Person]
AS
SELECT
    p.[IdNumber],
    p.[FirstNameStd],
    p.[LastNameStd],
    p.[BirthDate],
    p.[EmailStd],
    p.[PhoneStd],
    p.[PostalCode5],
    p.[HasStudentRecord]
FROM [staging].[Person] AS p;
