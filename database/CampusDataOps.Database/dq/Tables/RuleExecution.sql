-- Per-rule totals for one validation run; the scorecard's pass rate comes from here.
CREATE TABLE [dq].[RuleExecution] (
    [ValidationRunId]  BIGINT        NOT NULL,
    [RuleCode]         VARCHAR (40)  NOT NULL,
    [RecordsEvaluated] INT           NOT NULL,
    [RecordsFailed]    INT           NOT NULL,
    [CreatedAtUtc]     DATETIME2 (3) CONSTRAINT [DF_dq_RuleExecution_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_dq_RuleExecution] PRIMARY KEY CLUSTERED ([ValidationRunId] ASC, [RuleCode] ASC),
    CONSTRAINT [FK_dq_RuleExecution_ValidationRun] FOREIGN KEY ([ValidationRunId]) REFERENCES [dq].[ValidationRun] ([ValidationRunId]),
    CONSTRAINT [FK_dq_RuleExecution_Rule] FOREIGN KEY ([RuleCode]) REFERENCES [dq].[Rule] ([RuleCode]),
    CONSTRAINT [CK_dq_RuleExecution_Counts]
        CHECK ([RecordsEvaluated] >= 0 AND [RecordsFailed] >= 0 AND [RecordsFailed] <= [RecordsEvaluated])
);
