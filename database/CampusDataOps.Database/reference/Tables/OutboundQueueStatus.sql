CREATE TABLE [reference].[OutboundQueueStatus] (
    [QueueStatusCode] VARCHAR (20)   NOT NULL,
    [Description]     NVARCHAR (400) NOT NULL,
    [IsSendable]      BIT            NOT NULL,
    [IsTerminal]      BIT            NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_reference_OutboundQueueStatus_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_reference_OutboundQueueStatus_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_OutboundQueueStatus] PRIMARY KEY CLUSTERED ([QueueStatusCode] ASC),
    CONSTRAINT [CK_reference_OutboundQueueStatus_SendableNotTerminal] CHECK (NOT ([IsSendable] = 1 AND [IsTerminal] = 1))
);
