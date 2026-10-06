/*
Compliance seed (ADR-003, docs/specifications/report-catalog.md, extract-controls.md and
ipeds-measure-mapping.md). Same contract as reference_seed.sql: idempotent, inserts missing
rows, updates rows whose governed values differ, never deletes. A census rule version that has
snapshots must never change: add a new version and make it current instead.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- noqa: disable=RF01

BEGIN TRANSACTION;

DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

------------------------------------------------------------------------------------------
DECLARE @CensusRuleVersion TABLE (
    [RuleVersion]        VARCHAR (20)   NOT NULL,
    [Description]        NVARCHAR (400) NOT NULL,
    [FullTimeMinCredits] DECIMAL (4, 1) NOT NULL,
    [EffectiveFrom]      DATE           NOT NULL,
    [IsCurrent]          BIT            NOT NULL,
    PRIMARY KEY ([RuleVersion])
);

INSERT INTO @CensusRuleVersion ([RuleVersion], [Description], [FullTimeMinCredits], [EffectiveFrom], [IsCurrent])
VALUES
    ('CENSUS-1', N'Sections counted at the end of the census date; full-time at 12 or more credits.', 12.0, '2024-07-01', 1);

IF EXISTS (
    SELECT 1
    FROM [compliance].[CensusRuleVersion] AS t
    INNER JOIN @CensusRuleVersion AS s ON t.[RuleVersion] = s.[RuleVersion]
    WHERE t.[FullTimeMinCredits] <> s.[FullTimeMinCredits]
      AND EXISTS (SELECT 1 FROM [compliance].[CensusSnapshot] AS cs WHERE cs.[RuleVersion] = t.[RuleVersion])
)
    THROW 52020, N'A census rule version with snapshots cannot change; add a new version instead (ADR-003).', 1;

UPDATE t
SET t.[Description] = s.[Description],
    t.[FullTimeMinCredits] = s.[FullTimeMinCredits],
    t.[EffectiveFrom] = s.[EffectiveFrom],
    t.[IsCurrent] = s.[IsCurrent],
    t.[UpdatedAtUtc] = @NowUtc
FROM [compliance].[CensusRuleVersion] AS t
INNER JOIN @CensusRuleVersion AS s ON t.[RuleVersion] = s.[RuleVersion]
WHERE EXISTS (
    SELECT s.[Description], s.[FullTimeMinCredits], s.[EffectiveFrom], s.[IsCurrent]
    EXCEPT
    SELECT t.[Description], t.[FullTimeMinCredits], t.[EffectiveFrom], t.[IsCurrent]
);

INSERT INTO [compliance].[CensusRuleVersion] ([RuleVersion], [Description], [FullTimeMinCredits], [EffectiveFrom],
    [IsCurrent])
SELECT s.[RuleVersion], s.[Description], s.[FullTimeMinCredits], s.[EffectiveFrom], s.[IsCurrent]
FROM @CensusRuleVersion AS s
WHERE NOT EXISTS (SELECT 1 FROM [compliance].[CensusRuleVersion] AS t WHERE t.[RuleVersion] = s.[RuleVersion]);

-- noqa: enable=RF01

COMMIT TRANSACTION;
