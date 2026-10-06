-- Random surrogate keys for masked and Power BI outputs (docs/architecture/security-model.md).
-- Keys are assigned in random order by security.usp_AssignStudentPseudonyms, so StudentKey and
-- MaskedStudentId cannot be derived from the SIS ID without reading this table, which no
-- managed role can.
CREATE TABLE [security].[StudentPseudonym] (
    [IdNumber]        INT           NOT NULL,
    [StudentKey]      INT           IDENTITY (1, 1) NOT NULL,
    [MaskedStudentId] AS (CONVERT(CHAR (8), CONCAT('S', RIGHT(CONCAT('0000000', [StudentKey]), 7)))) PERSISTED NOT NULL,
    [AssignedAtUtc]   DATETIME2 (3) CONSTRAINT [DF_security_StudentPseudonym_AssignedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_security_StudentPseudonym] PRIMARY KEY CLUSTERED ([IdNumber] ASC),
    CONSTRAINT [UQ_security_StudentPseudonym_StudentKey] UNIQUE ([StudentKey])
);
