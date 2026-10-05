-- One row per record that failed a rule in a validation run. RecordKey and DetailCode carry
-- identifiers and codes only, never names, birth dates or contact values.
CREATE TABLE [dq].[RuleResult] (
    [RuleResultId]    BIGINT        IDENTITY (1, 1) NOT NULL,
    [ValidationRunId] BIGINT        NOT NULL,
    [RuleCode]        VARCHAR (40)  NOT NULL,
    [RecordKey]       VARCHAR (100) NOT NULL,
    [DetailCode]      VARCHAR (200) NULL,
    [CreatedAtUtc]    DATETIME2 (3) CONSTRAINT [DF_dq_RuleResult_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_dq_RuleResult] PRIMARY KEY CLUSTERED ([RuleResultId] ASC),
    CONSTRAINT [FK_dq_RuleResult_RuleExecution]
        FOREIGN KEY ([ValidationRunId], [RuleCode]) REFERENCES [dq].[RuleExecution] ([ValidationRunId], [RuleCode]),
    CONSTRAINT [UQ_dq_RuleResult_RunRuleRecord] UNIQUE ([ValidationRunId], [RuleCode], [RecordKey])
);
GO

CREATE NONCLUSTERED INDEX [IX_dq_RuleResult_RuleRecord]
    ON [dq].[RuleResult] ([RuleCode] ASC, [RecordKey] ASC, [ValidationRunId] ASC);
