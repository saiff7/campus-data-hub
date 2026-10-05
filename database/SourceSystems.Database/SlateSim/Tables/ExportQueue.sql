-- Models the CRM's scheduled export of admitted applicants to the SIS integration.
CREATE TABLE [SlateSim].[ExportQueue] (
    [ExportQueueId] BIGINT           NOT NULL,
    [ApplicationId] UNIQUEIDENTIFIER NOT NULL,
    [ExportType]    VARCHAR (30)     NOT NULL,
    [QueuedAtUtc]   DATETIME2 (3)    NOT NULL,
    [ExportedAtUtc] DATETIME2 (3)    NULL,
    [CreatedAtUtc]  DATETIME2 (3)    CONSTRAINT [DF_SlateSim_ExportQueue_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]  DATETIME2 (3)    CONSTRAINT [DF_SlateSim_ExportQueue_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_SlateSim_ExportQueue] PRIMARY KEY CLUSTERED ([ExportQueueId] ASC),
    CONSTRAINT [FK_SlateSim_ExportQueue_Application]
        FOREIGN KEY ([ApplicationId]) REFERENCES [SlateSim].[Application] ([ApplicationId]),
    CONSTRAINT [CK_SlateSim_ExportQueue_ExportType] CHECK (([ExportType] = 'ADMITTED_APPLICANT')),
    CONSTRAINT [CK_SlateSim_ExportQueue_ExportedAfterQueued]
        CHECK ([ExportedAtUtc] IS NULL OR [ExportedAtUtc] >= [QueuedAtUtc]),
    CONSTRAINT [UQ_SlateSim_ExportQueue_ApplicationType] UNIQUE ([ApplicationId], [ExportType])
);
GO

CREATE NONCLUSTERED INDEX [IX_SlateSim_ExportQueue_Pending]
    ON [SlateSim].[ExportQueue] ([QueuedAtUtc] ASC)
    INCLUDE ([ApplicationId], [ExportType])
    WHERE ([ExportedAtUtc] IS NULL);
