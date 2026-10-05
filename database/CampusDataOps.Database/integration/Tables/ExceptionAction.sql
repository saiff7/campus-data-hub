-- Append-only history of exception status changes. The composite foreign key to
-- reference.ExceptionStatusTransition means a disallowed transition cannot be recorded; the
-- creating action (no previous status) must open the exception.
CREATE TABLE [integration].[ExceptionAction] (
    [ExceptionActionId] BIGINT          IDENTITY (1, 1) NOT NULL,
    [ExceptionId]       BIGINT          NOT NULL,
    [FromStatusCode]    VARCHAR (30)    NULL,
    [ToStatusCode]      VARCHAR (30)    NOT NULL,
    [BatchId]           BIGINT          NULL,
    [ActionBy]          NVARCHAR (128)  NOT NULL,
    [ActionAtUtc]       DATETIME2 (3)   NOT NULL,
    [ReasonText]        NVARCHAR (400)  NOT NULL,
    [Note]              NVARCHAR (1000) NULL,
    [RecordedBy]        NVARCHAR (128)  CONSTRAINT [DF_integration_ExceptionAction_RecordedBy] DEFAULT (ORIGINAL_LOGIN()) NOT NULL,
    CONSTRAINT [PK_integration_ExceptionAction] PRIMARY KEY CLUSTERED ([ExceptionActionId] ASC),
    CONSTRAINT [FK_integration_ExceptionAction_Exception]
        FOREIGN KEY ([ExceptionId]) REFERENCES [integration].[IntegrationException] ([ExceptionId]),
    CONSTRAINT [FK_integration_ExceptionAction_ToStatus]
        FOREIGN KEY ([ToStatusCode]) REFERENCES [reference].[ExceptionStatus] ([ExceptionStatusCode]),
    CONSTRAINT [FK_integration_ExceptionAction_Transition]
        FOREIGN KEY ([FromStatusCode], [ToStatusCode])
        REFERENCES [reference].[ExceptionStatusTransition] ([FromStatusCode], [ToStatusCode]),
    CONSTRAINT [FK_integration_ExceptionAction_Batch] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [CK_integration_ExceptionAction_CreationOpens] CHECK ([FromStatusCode] IS NOT NULL OR [ToStatusCode] = 'OPEN'),
    CONSTRAINT [CK_integration_ExceptionAction_ReasonText] CHECK (LEN([ReasonText]) > 0)
);
GO

CREATE NONCLUSTERED INDEX [IX_integration_ExceptionAction_ExceptionId]
    ON [integration].[ExceptionAction] ([ExceptionId] ASC, [ExceptionActionId] ASC);
