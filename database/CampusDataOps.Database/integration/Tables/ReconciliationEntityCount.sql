-- Entity-level reconciliation: for each staged entity, the distinct source keys landed by
-- successful batches against the keys present in staging.
CREATE TABLE [integration].[ReconciliationEntityCount] (
    [BatchId]        BIGINT        NOT NULL,
    [EntityCode]     VARCHAR (30)  NOT NULL,
    [LandedKeyCount] INT           NOT NULL,
    [StagedKeyCount] INT           NOT NULL,
    [IsBalanced]     AS (CONVERT(BIT, CASE WHEN [LandedKeyCount] = [StagedKeyCount] THEN 1 ELSE 0 END)) PERSISTED,
    [CreatedAtUtc]   DATETIME2 (3) CONSTRAINT [DF_integration_ReconciliationEntityCount_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_integration_ReconciliationEntityCount] PRIMARY KEY CLUSTERED ([BatchId] ASC, [EntityCode] ASC),
    CONSTRAINT [FK_integration_ReconciliationEntityCount_Batch] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [CK_integration_ReconciliationEntityCount_EntityCode]
        CHECK (([EntityCode] = 'SLATE_APPLICATION' OR [EntityCode] = 'J1_PERSON' OR [EntityCode] = 'J1_ENROLLMENT'
            OR [EntityCode] = 'J1_FINANCIAL_AID' OR [EntityCode] = 'J1_ACCOUNT_TRANSACTION' OR [EntityCode] = 'DIRECTORY_ACCOUNT')),
    CONSTRAINT [CK_integration_ReconciliationEntityCount_NonNegative] CHECK ([LandedKeyCount] >= 0 AND [StagedKeyCount] >= 0)
);
