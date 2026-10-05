-- Ordered deterministic match rules (docs/specifications/matching-rules.md). Only rules with
-- IsAutoMatchEligible = 1 may produce an AUTO_MATCH, and integration.MatchDecision enforces
-- the same list in a CHECK constraint.
CREATE TABLE [reference].[MatchRule] (
    [RuleCode]            VARCHAR (20)   NOT NULL,
    [Priority]            TINYINT        NOT NULL,
    [Description]         NVARCHAR (400) NOT NULL,
    [ConfidenceCategory]  VARCHAR (10)   NOT NULL,
    [IsAutoMatchEligible] BIT            NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_MatchRule_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_MatchRule_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_MatchRule] PRIMARY KEY CLUSTERED ([RuleCode] ASC),
    CONSTRAINT [UQ_reference_MatchRule_Priority] UNIQUE ([Priority]),
    CONSTRAINT [CK_reference_MatchRule_ConfidenceCategory]
        CHECK (([ConfidenceCategory] = 'EXACT' OR [ConfidenceCategory] = 'HIGH' OR [ConfidenceCategory] = 'REVIEW'))
);
