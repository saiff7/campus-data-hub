-- One execution of the data-quality suite. A batch has at most one run; the suite returns
-- the existing run instead of duplicating it.
CREATE TABLE [dq].[ValidationRun] (
    [ValidationRunId] BIGINT        IDENTITY (1, 1) NOT NULL,
    [BatchId]         BIGINT        NOT NULL,
    [StartedAtUtc]    DATETIME2 (3) NOT NULL,
    [EndedAtUtc]      DATETIME2 (3) NOT NULL,
    [RulesEvaluated]  INT           NOT NULL,
    [FailuresFound]   INT           NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3) CONSTRAINT [DF_dq_ValidationRun_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_dq_ValidationRun] PRIMARY KEY CLUSTERED ([ValidationRunId] ASC),
    CONSTRAINT [FK_dq_ValidationRun_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [UQ_dq_ValidationRun_BatchId] UNIQUE ([BatchId]),
    CONSTRAINT [CK_dq_ValidationRun_EndAfterStart] CHECK ([EndedAtUtc] >= [StartedAtUtc]),
    CONSTRAINT [CK_dq_ValidationRun_Counts] CHECK ([RulesEvaluated] >= 0 AND [FailuresFound] >= 0)
);
