CREATE TABLE [audit].[BatchStep] (
    [BatchStepId]         BIGINT        IDENTITY (1, 1) NOT NULL,
    [BatchId]             BIGINT        NOT NULL,
    [StepName]            VARCHAR (100) NOT NULL,
    [StepOrder]           SMALLINT      NOT NULL,
    [AttemptNumber]       SMALLINT      CONSTRAINT [DF_audit_BatchStep_AttemptNumber] DEFAULT (1) NOT NULL,
    [BatchStepStatusCode] VARCHAR (20)  NOT NULL,
    [StartedAtUtc]        DATETIME2 (3) NOT NULL,
    [EndedAtUtc]          DATETIME2 (3) NULL,
    [RowsAffected]        INT           NULL,
    [CreatedAtUtc]        DATETIME2 (3) CONSTRAINT [DF_audit_BatchStep_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3) CONSTRAINT [DF_audit_BatchStep_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_audit_BatchStep] PRIMARY KEY CLUSTERED ([BatchStepId] ASC),
    CONSTRAINT [FK_audit_BatchStep_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_audit_BatchStep_BatchStepStatus]
        FOREIGN KEY ([BatchStepStatusCode]) REFERENCES [reference].[BatchStepStatus] ([BatchStepStatusCode]),
    CONSTRAINT [UQ_audit_BatchStep_BatchStepAttempt] UNIQUE ([BatchId], [StepName], [AttemptNumber]),
    CONSTRAINT [CK_audit_BatchStep_StepOrder] CHECK ([StepOrder] > 0),
    CONSTRAINT [CK_audit_BatchStep_AttemptNumber] CHECK ([AttemptNumber] > 0),
    CONSTRAINT [CK_audit_BatchStep_EndAfterStart] CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc]),
    CONSTRAINT [CK_audit_BatchStep_RowsAffected] CHECK ([RowsAffected] IS NULL OR [RowsAffected] >= 0)
);
