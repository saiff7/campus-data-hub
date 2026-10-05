-- Controlled writes from CampusDataOps to the J1-Sim import interface
-- (docs/specifications/integration-controls.md). IdempotencyKey is SHA-256 of source system,
-- application, action and target ID number; J1-Sim records the same key in its receipt, so a
-- replay can never create a second person. At most one live (non-cancelled) row exists per
-- application. ReconciledBatchId marks the run whose reconciliation counted the success.
CREATE TABLE [integration].[OutboundStudentQueue] (
    [QueueId]           BIGINT           IDENTITY (1, 1) NOT NULL,
    [IdempotencyKey]    BINARY (32)      NOT NULL,
    [ApplicationId]     UNIQUEIDENTIFIER NOT NULL,
    [SlatePersonId]     UNIQUEIDENTIFIER NOT NULL,
    [ActionCode]        VARCHAR (30)     NOT NULL,
    [TargetIdNumber]    INT              NULL,
    [MatchDecisionId]   BIGINT           NOT NULL,
    [FirstName]         NVARCHAR (100)   NOT NULL,
    [MiddleName]        NVARCHAR (100)   NULL,
    [LastName]          NVARCHAR (100)   NOT NULL,
    [BirthDate]         DATE             NOT NULL,
    [Email]             NVARCHAR (320)   NULL,
    [Phone]             VARCHAR (10)     NULL,
    [AddressLine1]      NVARCHAR (200)   NULL,
    [City]              NVARCHAR (100)   NULL,
    [StateCode]         CHAR (2)         NULL,
    [PostalCode]        VARCHAR (10)     NULL,
    [J1ProgramCode]     VARCHAR (20)     NOT NULL,
    [EntryTermCode]     VARCHAR (10)     NOT NULL,
    [ResidencyCode]     VARCHAR (20)     NOT NULL,
    [QueueStatusCode]   VARCHAR (20)     NOT NULL,
    [AttemptCount]      SMALLINT         CONSTRAINT [DF_integration_OutboundStudentQueue_AttemptCount] DEFAULT (0) NOT NULL,
    [MaxAttempts]       SMALLINT         CONSTRAINT [DF_integration_OutboundStudentQueue_MaxAttempts] DEFAULT (3) NOT NULL,
    [RetryGeneration]   SMALLINT         CONSTRAINT [DF_integration_OutboundStudentQueue_RetryGeneration] DEFAULT (0) NOT NULL,
    [LastAttemptAtUtc]  DATETIME2 (3)    NULL,
    [LastErrorLogId]    BIGINT           NULL,
    [ResultIdNumber]    INT              NULL,
    [CompletedAtUtc]    DATETIME2 (3)    NULL,
    [QueuedBatchId]     BIGINT           NOT NULL,
    [ProcessedBatchId]  BIGINT           NULL,
    [ReconciledBatchId] BIGINT           NULL,
    [CreatedAtUtc]      DATETIME2 (3)    CONSTRAINT [DF_integration_OutboundStudentQueue_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]      DATETIME2 (3)    CONSTRAINT [DF_integration_OutboundStudentQueue_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_integration_OutboundStudentQueue] PRIMARY KEY CLUSTERED ([QueueId] ASC),
    CONSTRAINT [UQ_integration_OutboundStudentQueue_IdempotencyKey] UNIQUE ([IdempotencyKey]),
    CONSTRAINT [FK_integration_OutboundStudentQueue_Action]
        FOREIGN KEY ([ActionCode]) REFERENCES [reference].[OutboundAction] ([ActionCode]),
    CONSTRAINT [FK_integration_OutboundStudentQueue_Status]
        FOREIGN KEY ([QueueStatusCode]) REFERENCES [reference].[OutboundQueueStatus] ([QueueStatusCode]),
    CONSTRAINT [FK_integration_OutboundStudentQueue_Decision]
        FOREIGN KEY ([MatchDecisionId]) REFERENCES [integration].[MatchDecision] ([MatchDecisionId]),
    CONSTRAINT [FK_integration_OutboundStudentQueue_LastError]
        FOREIGN KEY ([LastErrorLogId]) REFERENCES [audit].[ErrorLog] ([ErrorLogId]),
    CONSTRAINT [FK_integration_OutboundStudentQueue_QueuedBatch]
        FOREIGN KEY ([QueuedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_integration_OutboundStudentQueue_ProcessedBatch]
        FOREIGN KEY ([ProcessedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_integration_OutboundStudentQueue_ReconciledBatch]
        FOREIGN KEY ([ReconciledBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [CK_integration_OutboundStudentQueue_Target]
        CHECK (([ActionCode] = 'CREATE_PERSON_STUDENT' AND [TargetIdNumber] IS NULL)
            OR ([ActionCode] <> 'CREATE_PERSON_STUDENT' AND [TargetIdNumber] IS NOT NULL)),
    CONSTRAINT [CK_integration_OutboundStudentQueue_Attempts]
        CHECK ([AttemptCount] >= 0 AND [MaxAttempts] > 0 AND [AttemptCount] <= [MaxAttempts] AND [RetryGeneration] >= 0),
    CONSTRAINT [CK_integration_OutboundStudentQueue_Succeeded]
        CHECK (([QueueStatusCode] = 'SUCCEEDED' AND [ResultIdNumber] IS NOT NULL AND [CompletedAtUtc] IS NOT NULL
                AND [ProcessedBatchId] IS NOT NULL)
            OR ([QueueStatusCode] <> 'SUCCEEDED' AND [ResultIdNumber] IS NULL AND [ReconciledBatchId] IS NULL))
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_integration_OutboundStudentQueue_OneLivePerApplication]
    ON [integration].[OutboundStudentQueue] ([ApplicationId] ASC)
    INCLUDE ([QueueStatusCode], [IdempotencyKey])
    WHERE ([QueueStatusCode] <> 'CANCELLED');
GO

CREATE NONCLUSTERED INDEX [IX_integration_OutboundStudentQueue_Sendable]
    ON [integration].[OutboundStudentQueue] ([QueueStatusCode] ASC, [QueueId] ASC)
    INCLUDE ([AttemptCount], [MaxAttempts]);
