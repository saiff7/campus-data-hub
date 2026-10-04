CREATE TABLE [DirectorySim].[AccountStatusHistory] (
    [AccountStatusHistoryId] BIGINT           NOT NULL,
    [AccountGuid]            UNIQUEIDENTIFIER NOT NULL,
    [IsEnabled]              BIT              NOT NULL,
    [Reason]                 VARCHAR (100)    NOT NULL,
    [ChangedAtUtc]           DATETIME2 (3)    NOT NULL,
    [CreatedAtUtc]           DATETIME2 (3)    CONSTRAINT [DF_DirectorySim_AccountStatusHistory_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_DirectorySim_AccountStatusHistory] PRIMARY KEY CLUSTERED ([AccountStatusHistoryId] ASC),
    CONSTRAINT [FK_DirectorySim_AccountStatusHistory_DirectoryAccount]
        FOREIGN KEY ([AccountGuid]) REFERENCES [DirectorySim].[DirectoryAccount] ([AccountGuid]),
    CONSTRAINT [UQ_DirectorySim_AccountStatusHistory_AccountTime] UNIQUE ([AccountGuid], [ChangedAtUtc])
);
