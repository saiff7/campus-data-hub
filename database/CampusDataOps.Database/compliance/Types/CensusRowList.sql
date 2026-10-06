-- Census snapshot rows, passed to compliance.fn_CensusRowsChecksum so capture and verification
-- serialize rows in exactly one place.
CREATE TYPE [compliance].[CensusRowList] AS TABLE (
    [IdNumber]            INT            NOT NULL PRIMARY KEY,
    [ProgramCode]         VARCHAR (20)   NULL,
    [EntryTermCode]       VARCHAR (10)   NULL,
    [StudentStatus]       VARCHAR (20)   NULL,
    [ResidencyCode]       VARCHAR (20)   NULL,
    [CensusCredits]       DECIMAL (5, 1) NOT NULL,
    [CountedSections]     SMALLINT       NOT NULL,
    [AttendanceIntensity] VARCHAR (10)   NULL,
    [EntryStatus]         VARCHAR (10)   NULL,
    [AgeAtCensus]         TINYINT        NULL,
    [IsCensusIncluded]    BIT            NOT NULL,
    [ExclusionReason]     VARCHAR (30)   NULL
);
