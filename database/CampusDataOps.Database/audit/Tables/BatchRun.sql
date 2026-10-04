-- One row per execution of a process (a source landing load or a scheduled job).
-- Watermarks advance only on SUCCEEDED landing batches; the landing procedures enforce it.
CREATE TABLE [audit].[BatchRun] (
    [BatchId]              BIGINT         IDENTITY (1, 1) NOT NULL,
    [ProcessName]          VARCHAR (100)  NOT NULL,
    [SourceSystemCode]     VARCHAR (20)   NULL,
    [BatchStatusCode]      VARCHAR (20)   NOT NULL,
    [RequestedAtUtc]       DATETIME2 (3)  NOT NULL,
    [StartedAtUtc]         DATETIME2 (3)  NOT NULL,
    [EndedAtUtc]           DATETIME2 (3)  NULL,
    [InvokedBy]            NVARCHAR (128) CONSTRAINT [DF_audit_BatchRun_InvokedBy] DEFAULT (ORIGINAL_LOGIN()) NOT NULL,
    [PreviousWatermarkUtc] DATETIME2 (3)  NULL,
    [SourceWatermarkUtc]   DATETIME2 (3)  NULL,
    [RowsRead]             INT            NULL,
    [RowsInserted]         INT            NULL,
    [RowsUpdated]          INT            NULL,
    [RowsUnchanged]        INT            NULL,
    [RowsRejected]         INT            NULL,
    [ExceptionCount]       INT            NULL,
    [CreatedAtUtc]         DATETIME2 (3)  CONSTRAINT [DF_audit_BatchRun_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]         DATETIME2 (3)  CONSTRAINT [DF_audit_BatchRun_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_audit_BatchRun] PRIMARY KEY CLUSTERED ([BatchId] ASC),
    CONSTRAINT [FK_audit_BatchRun_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [FK_audit_BatchRun_BatchStatus]
        FOREIGN KEY ([BatchStatusCode]) REFERENCES [reference].[BatchStatus] ([BatchStatusCode]),
    CONSTRAINT [CK_audit_BatchRun_StartAfterRequest] CHECK ([StartedAtUtc] >= [RequestedAtUtc]),
    CONSTRAINT [CK_audit_BatchRun_EndAfterStart] CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc]),
    CONSTRAINT [CK_audit_BatchRun_RunningHasNoEnd]
        CHECK (([BatchStatusCode] = 'RUNNING' AND [EndedAtUtc] IS NULL)
            OR ([BatchStatusCode] <> 'RUNNING' AND [EndedAtUtc] IS NOT NULL)),
    CONSTRAINT [CK_audit_BatchRun_WatermarkForward]
        CHECK ([SourceWatermarkUtc] IS NULL OR [PreviousWatermarkUtc] IS NULL OR [SourceWatermarkUtc] >= [PreviousWatermarkUtc]),
    CONSTRAINT [CK_audit_BatchRun_NonNegativeCounts]
        CHECK (ISNULL([RowsRead], 0) >= 0 AND ISNULL([RowsInserted], 0) >= 0 AND ISNULL([RowsUpdated], 0) >= 0
            AND ISNULL([RowsUnchanged], 0) >= 0 AND ISNULL([RowsRejected], 0) >= 0 AND ISNULL([ExceptionCount], 0) >= 0)
);
GO

-- Database-enforced guard: a process can have at most one RUNNING batch at a time.
CREATE UNIQUE NONCLUSTERED INDEX [UX_audit_BatchRun_OneRunningPerProcess]
    ON [audit].[BatchRun] ([ProcessName] ASC)
    WHERE ([BatchStatusCode] = 'RUNNING');
GO

CREATE NONCLUSTERED INDEX [IX_audit_BatchRun_ProcessStatus]
    ON [audit].[BatchRun] ([ProcessName] ASC, [BatchStatusCode] ASC, [BatchId] DESC)
    INCLUDE ([SourceWatermarkUtc], [EndedAtUtc]);
