-- Registry of governed measures (docs/specifications/report-catalog.md R6): every leadership
-- measure has one definition, owner, grain, inclusion rule, as-of behavior and lineage.
-- IsAssumption marks a definition this project chose and an owner must approve.
CREATE TABLE [compliance].[MeasureDefinition] (
    [MeasureCode]         VARCHAR (40)   NOT NULL,
    [MeasureName]         NVARCHAR (100) NOT NULL,
    [Definition]          NVARCHAR (600) NOT NULL,
    [Unit]                VARCHAR (10)   NOT NULL,
    [OwnerDepartmentCode] VARCHAR (30)   NOT NULL,
    [Grain]               NVARCHAR (100) NOT NULL,
    [InclusionRule]       NVARCHAR (400) NOT NULL,
    [AsOfBehavior]        VARCHAR (15)   NOT NULL,
    [SourceLineage]       NVARCHAR (400) NOT NULL,
    [IsAssumption]        BIT            NOT NULL,
    [SortOrder]           TINYINT        NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_compliance_MeasureDefinition_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_compliance_MeasureDefinition_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_compliance_MeasureDefinition] PRIMARY KEY CLUSTERED ([MeasureCode] ASC),
    CONSTRAINT [FK_compliance_MeasureDefinition_Department]
        FOREIGN KEY ([OwnerDepartmentCode]) REFERENCES [reference].[Department] ([DepartmentCode]),
    CONSTRAINT [CK_compliance_MeasureDefinition_Unit]
        CHECK (([Unit] = 'COUNT' OR [Unit] = 'RATIO' OR [Unit] = 'USD' OR [Unit] = 'FTE')),
    CONSTRAINT [CK_compliance_MeasureDefinition_AsOfBehavior]
        CHECK (([AsOfBehavior] = 'CENSUS_SNAPSHOT' OR [AsOfBehavior] = 'CURRENT'))
);
