-- Power BI student dimension: masked (random surrogate key, attributes only).
CREATE VIEW [bi].[DimStudent]
AS
SELECT
    m.[StudentKey],
    m.[MaskedStudentId],
    m.[ProgramCode],
    m.[EntryTermCode],
    m.[StudentStatus],
    m.[ResidencyCode],
    m.[AgeBand]
FROM [security].[vw_StudentMasked] AS m;
