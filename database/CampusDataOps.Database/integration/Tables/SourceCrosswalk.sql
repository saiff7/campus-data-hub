-- Confirmed links between a source-system person and a J1-Sim ID number. A row is written
-- only in the same transaction as a successful J1-Sim write, so it always describes a link
-- the target accepted. Both directions are unique per source system: one Slate-Sim person
-- maps to one J1-Sim person and vice versa, so a second claim surfaces as an identity issue.
CREATE TABLE [integration].[SourceCrosswalk] (
    [SourceCrosswalkId] BIGINT        IDENTITY (1, 1) NOT NULL,
    [SourceSystemCode]  VARCHAR (20)  NOT NULL,
    [SourceRecordId]    VARCHAR (64)  NOT NULL,
    [TargetIdNumber]    INT           NOT NULL,
    [CreatedByQueueId]  BIGINT        NOT NULL,
    [CreatedBatchId]    BIGINT        NOT NULL,
    [CreatedAtUtc]      DATETIME2 (3) CONSTRAINT [DF_integration_SourceCrosswalk_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_integration_SourceCrosswalk] PRIMARY KEY CLUSTERED ([SourceCrosswalkId] ASC),
    CONSTRAINT [FK_integration_SourceCrosswalk_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [FK_integration_SourceCrosswalk_Queue]
        FOREIGN KEY ([CreatedByQueueId]) REFERENCES [integration].[OutboundStudentQueue] ([QueueId]),
    CONSTRAINT [FK_integration_SourceCrosswalk_Batch] FOREIGN KEY ([CreatedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [UQ_integration_SourceCrosswalk_Source] UNIQUE ([SourceSystemCode], [SourceRecordId]),
    CONSTRAINT [UQ_integration_SourceCrosswalk_Target] UNIQUE ([SourceSystemCode], [TargetIdNumber])
);
