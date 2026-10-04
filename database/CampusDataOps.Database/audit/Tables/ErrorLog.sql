-- Error text comes from the engine and may quote key values; procedures must not raise
-- custom messages that embed personal data (names, birth dates, contact values).
CREATE TABLE [audit].[ErrorLog] (
    [ErrorLogId]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [BatchId]        BIGINT          NULL,
    [BatchStepId]    BIGINT          NULL,
    [ErrorNumber]    INT             NOT NULL,
    [ErrorSeverity]  INT             NOT NULL,
    [ErrorState]     INT             NOT NULL,
    [ErrorProcedure] NVARCHAR (128)  NULL,
    [ErrorLine]      INT             NULL,
    [ErrorMessage]   NVARCHAR (4000) NOT NULL,
    [LoggedBy]       NVARCHAR (128)  CONSTRAINT [DF_audit_ErrorLog_LoggedBy] DEFAULT (ORIGINAL_LOGIN()) NOT NULL,
    [LoggedAtUtc]    DATETIME2 (3)   CONSTRAINT [DF_audit_ErrorLog_LoggedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_audit_ErrorLog] PRIMARY KEY CLUSTERED ([ErrorLogId] ASC),
    CONSTRAINT [FK_audit_ErrorLog_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_audit_ErrorLog_BatchStep] FOREIGN KEY ([BatchStepId]) REFERENCES [audit].[BatchStep] ([BatchStepId])
);
GO

CREATE NONCLUSTERED INDEX [IX_audit_ErrorLog_BatchId]
    ON [audit].[ErrorLog] ([BatchId] ASC)
    WHERE ([BatchId] IS NOT NULL);
