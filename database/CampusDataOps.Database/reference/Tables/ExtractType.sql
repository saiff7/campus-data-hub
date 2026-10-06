-- Every extract the platform produces (docs/specifications/extract-controls.md). AccessRoleName
-- is the department role allowed to generate and export it (the integration service and
-- db_owner may too). Only aggregate types may be public-safe. GeneratorVersion changes whenever
-- the builder's output changes.
CREATE TABLE [reference].[ExtractType] (
    [ExtractTypeCode]     VARCHAR (30)   NOT NULL,
    [Description]         NVARCHAR (400) NOT NULL,
    [Grain]               NVARCHAR (200) NOT NULL,
    [OwnerDepartmentCode] VARCHAR (30)   NOT NULL,
    [SecurityClass]       VARCHAR (25)   NOT NULL,
    [PeriodType]          VARCHAR (15)   NOT NULL,
    [AccessRoleName]      NVARCHAR (128) NOT NULL,
    [IsPublicSafe]        BIT            NOT NULL,
    [IsPrivileged]        BIT            NOT NULL,
    [GeneratorVersion]    VARCHAR (10)   NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_ExtractType_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_ExtractType_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ExtractType] PRIMARY KEY CLUSTERED ([ExtractTypeCode] ASC),
    CONSTRAINT [FK_reference_ExtractType_Department]
        FOREIGN KEY ([OwnerDepartmentCode]) REFERENCES [reference].[Department] ([DepartmentCode]),
    CONSTRAINT [CK_reference_ExtractType_SecurityClass]
        CHECK (([SecurityClass] = 'CONFIDENTIAL_STUDENT' OR [SecurityClass] = 'INTERNAL_MASKED'
            OR [SecurityClass] = 'INTERNAL_AGGREGATE')),
    CONSTRAINT [CK_reference_ExtractType_PeriodType]
        CHECK (([PeriodType] = 'TERM' OR [PeriodType] = 'ACADEMIC_YEAR' OR [PeriodType] = 'AS_OF_DATE' OR [PeriodType] = 'NONE')),
    CONSTRAINT [CK_reference_ExtractType_PublicSafe] CHECK ([IsPublicSafe] = 0 OR [SecurityClass] = 'INTERNAL_AGGREGATE'),
    CONSTRAINT [CK_reference_ExtractType_Privileged] CHECK ([IsPrivileged] = 1 OR [SecurityClass] <> 'CONFIDENTIAL_STUDENT')
);
