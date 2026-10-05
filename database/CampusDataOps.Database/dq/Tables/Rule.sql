-- Metadata for each data-quality rule (docs/specifications/data-quality-rules.md). The check
-- procedures evaluate a rule only while it is active and effective; CheckProcedure names the
-- procedure that implements it, for traceability.
CREATE TABLE [dq].[Rule] (
    [RuleCode]            VARCHAR (40)   NOT NULL,
    [Description]         NVARCHAR (400) NOT NULL,
    [EntityName]          VARCHAR (40)   NOT NULL,
    [Severity]            VARCHAR (10)   NOT NULL,
    [OwnerDepartment]     NVARCHAR (100) NOT NULL,
    [EffectiveFrom]       DATE           NOT NULL,
    [IsActive]            BIT            NOT NULL,
    [ExpectedCondition]   NVARCHAR (400) NOT NULL,
    [RemediationGuidance] NVARCHAR (800) NOT NULL,
    [CheckProcedure]      NVARCHAR (256) NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_dq_Rule_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_dq_Rule_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_dq_Rule] PRIMARY KEY CLUSTERED ([RuleCode] ASC),
    CONSTRAINT [CK_dq_Rule_Severity] CHECK (([Severity] = 'HIGH' OR [Severity] = 'MEDIUM' OR [Severity] = 'LOW'))
);
