-- Batch-level reconciliation, one row per pipeline run. The CHECK constraint is the invariant
-- from the blueprint: the mutually exclusive outcome counts must add up to the eligible count,
-- so an unbalanced summary cannot be stored. A run is balanced when every processed
-- application is confirmed in J1-Sim and every entity count agrees.
CREATE TABLE [integration].[ReconciliationResult] (
    [BatchId]             BIGINT        NOT NULL,
    [SourceEligible]      INT           NOT NULL,
    [Unchanged]           INT           NOT NULL,
    [Matched]             INT           NOT NULL,
    [Created]             INT           NOT NULL,
    [Rejected]            INT           NOT NULL,
    [Pending]             INT           NOT NULL,
    [Processed]           AS ([Matched] + [Created]) PERSISTED,
    [TargetConfirmed]     INT           NOT NULL,
    [EntityMismatchCount] INT           NOT NULL,
    [IsBalanced]          AS (CONVERT(BIT, CASE WHEN [TargetConfirmed] = [Matched] + [Created] AND [EntityMismatchCount] = 0 THEN 1 ELSE 0 END)) PERSISTED,
    [CreatedAtUtc]        DATETIME2 (3) CONSTRAINT [DF_integration_ReconciliationResult_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_integration_ReconciliationResult] PRIMARY KEY CLUSTERED ([BatchId] ASC),
    CONSTRAINT [FK_integration_ReconciliationResult_Batch] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [CK_integration_ReconciliationResult_OutcomesEqualEligible]
        CHECK ([SourceEligible] = [Unchanged] + [Matched] + [Created] + [Rejected] + [Pending]),
    CONSTRAINT [CK_integration_ReconciliationResult_ConfirmedWithinProcessed] CHECK ([TargetConfirmed] <= [Matched] + [Created]),
    CONSTRAINT [CK_integration_ReconciliationResult_NonNegative]
        CHECK ([SourceEligible] >= 0 AND [Unchanged] >= 0 AND [Matched] >= 0 AND [Created] >= 0 AND [Rejected] >= 0
            AND [Pending] >= 0 AND [TargetConfirmed] >= 0 AND [EntityMismatchCount] >= 0)
);
