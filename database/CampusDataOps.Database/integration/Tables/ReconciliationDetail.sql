-- Record-level reconciliation: exactly one outcome per eligible application per run. The
-- primary key makes outcomes mutually exclusive (docs/specifications/integration-controls.md).
CREATE TABLE [integration].[ReconciliationDetail] (
    [BatchId]             BIGINT           NOT NULL,
    [ApplicationId]       UNIQUEIDENTIFIER NOT NULL,
    [OutcomeCode]         VARCHAR (20)     NOT NULL,
    [ExceptionReasonCode] VARCHAR (40)     NULL,
    [QueueId]             BIGINT           NULL,
    [TargetIdNumber]      INT              NULL,
    [IsTargetConfirmed]   BIT              NULL,
    [CreatedAtUtc]        DATETIME2 (3)    NOT NULL
        CONSTRAINT [DF_integration_ReconciliationDetail_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_integration_ReconciliationDetail] PRIMARY KEY CLUSTERED ([BatchId] ASC, [ApplicationId] ASC),
    CONSTRAINT [FK_integration_ReconciliationDetail_Batch] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_integration_ReconciliationDetail_Outcome]
        FOREIGN KEY ([OutcomeCode]) REFERENCES [reference].[ReconciliationOutcome] ([OutcomeCode]),
    CONSTRAINT [FK_integration_ReconciliationDetail_Reason]
        FOREIGN KEY ([ExceptionReasonCode]) REFERENCES [reference].[ExceptionReason] ([ExceptionReasonCode]),
    CONSTRAINT [FK_integration_ReconciliationDetail_Queue]
        FOREIGN KEY ([QueueId]) REFERENCES [integration].[OutboundStudentQueue] ([QueueId]),
    CONSTRAINT [CK_integration_ReconciliationDetail_RejectedHasReason]
        CHECK (([OutcomeCode] = 'REJECTED' AND [ExceptionReasonCode] IS NOT NULL)
            OR ([OutcomeCode] <> 'REJECTED' AND [ExceptionReasonCode] IS NULL)),
    CONSTRAINT [CK_integration_ReconciliationDetail_ProcessedIsConfirmed]
        CHECK ((([OutcomeCode] = 'CREATED' OR [OutcomeCode] = 'MATCHED')
                AND [QueueId] IS NOT NULL AND [TargetIdNumber] IS NOT NULL AND [IsTargetConfirmed] IS NOT NULL)
            OR ([OutcomeCode] <> 'CREATED' AND [OutcomeCode] <> 'MATCHED' AND [IsTargetConfirmed] IS NULL))
);
