-- Versioned census rules (ADR-003). Changing a rule means adding a version and capturing a new
-- snapshot beside the old one; exactly one version is current.
CREATE TABLE [compliance].[CensusRuleVersion] (
    [RuleVersion]        VARCHAR (20)   NOT NULL,
    [Description]        NVARCHAR (400) NOT NULL,
    [FullTimeMinCredits] DECIMAL (4, 1) NOT NULL,
    [EffectiveFrom]      DATE           NOT NULL,
    [IsCurrent]          BIT            NOT NULL,
    [CreatedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_compliance_CensusRuleVersion_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_compliance_CensusRuleVersion_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_compliance_CensusRuleVersion] PRIMARY KEY CLUSTERED ([RuleVersion] ASC),
    CONSTRAINT [CK_compliance_CensusRuleVersion_FullTimeMinCredits] CHECK ([FullTimeMinCredits] > 0)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_compliance_CensusRuleVersion_Current]
    ON [compliance].[CensusRuleVersion] ([IsCurrent] ASC)
    WHERE ([IsCurrent] = 1);
