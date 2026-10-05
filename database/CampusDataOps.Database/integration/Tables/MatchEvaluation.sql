-- One row per application evaluated by the match rules in a batch. Candidates and the
-- resulting decision hang off it, so every decision traces back to the run and the staged
-- source version (SourceHash) it was made from.
CREATE TABLE [integration].[MatchEvaluation] (
    [MatchEvaluationId] BIGINT           IDENTITY (1, 1) NOT NULL,
    [BatchId]           BIGINT           NOT NULL,
    [ApplicationId]     UNIQUEIDENTIFIER NOT NULL,
    [SourceHash]        BINARY (32)      NOT NULL,
    [EvaluatedAtUtc]    DATETIME2 (3)    CONSTRAINT [DF_integration_MatchEvaluation_EvaluatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_integration_MatchEvaluation] PRIMARY KEY CLUSTERED ([MatchEvaluationId] ASC),
    CONSTRAINT [FK_integration_MatchEvaluation_Batch] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [UQ_integration_MatchEvaluation_BatchApplication] UNIQUE ([BatchId], [ApplicationId])
);
