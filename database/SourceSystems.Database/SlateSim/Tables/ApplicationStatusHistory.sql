CREATE TABLE [SlateSim].[ApplicationStatusHistory] (
    [ApplicationStatusHistoryId] BIGINT           NOT NULL,
    [ApplicationId]              UNIQUEIDENTIFIER NOT NULL,
    [Status]                     VARCHAR (20)     NOT NULL,
    [ChangedAtUtc]               DATETIME2 (3)    NOT NULL,
    [CreatedAtUtc]               DATETIME2 (3) NOT NULL
        CONSTRAINT [DF_SlateSim_ApplicationStatusHistory_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_SlateSim_ApplicationStatusHistory] PRIMARY KEY CLUSTERED ([ApplicationStatusHistoryId] ASC),
    CONSTRAINT [FK_SlateSim_ApplicationStatusHistory_Application]
        FOREIGN KEY ([ApplicationId]) REFERENCES [SlateSim].[Application] ([ApplicationId]),
    CONSTRAINT [CK_SlateSim_ApplicationStatusHistory_Status]
        CHECK (([Status] = 'STARTED' OR [Status] = 'SUBMITTED' OR [Status] = 'COMPLETE' OR [Status] = 'ADMITTED' OR [Status] = 'DENIED'
            OR [Status] = 'WITHDRAWN' OR [Status] = 'DEPOSITED')),
    CONSTRAINT [UQ_SlateSim_ApplicationStatusHistory_ApplicationStatusTime]
        UNIQUE ([ApplicationId], [ChangedAtUtc], [Status])
);
