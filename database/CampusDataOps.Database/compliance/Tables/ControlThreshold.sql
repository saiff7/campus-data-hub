-- Allowed change of a control's value against the latest earlier run of the same extract type.
-- Exceeding it is a WARN, never a FAIL (docs/specifications/extract-controls.md). The values are
-- project assumptions for Institutional Research to tune.
CREATE TABLE [compliance].[ControlThreshold] (
    [ExtractTypeCode] VARCHAR (30)  NOT NULL,
    [ControlCode]     VARCHAR (40)  NOT NULL,
    [MaxChangePct]    DECIMAL (9, 2) NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3) CONSTRAINT [DF_compliance_ControlThreshold_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3) CONSTRAINT [DF_compliance_ControlThreshold_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_compliance_ControlThreshold] PRIMARY KEY CLUSTERED ([ExtractTypeCode] ASC, [ControlCode] ASC),
    CONSTRAINT [FK_compliance_ControlThreshold_ExtractType]
        FOREIGN KEY ([ExtractTypeCode]) REFERENCES [reference].[ExtractType] ([ExtractTypeCode]),
    CONSTRAINT [CK_compliance_ControlThreshold_MaxChangePct] CHECK ([MaxChangePct] > 0)
);
