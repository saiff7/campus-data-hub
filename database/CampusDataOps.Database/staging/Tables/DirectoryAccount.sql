-- Current state of each Directory-Sim account. EmployeeIdNumber is the EmployeeId parsed as a
-- J1-Sim ID number when it is exactly seven digits; the raw text is kept beside it.
CREATE TABLE [staging].[DirectoryAccount] (
    [AccountGuid]       UNIQUEIDENTIFIER NOT NULL,
    [LandingRowId]      BIGINT           NOT NULL,
    [SamAccountName]    VARCHAR (64)     NOT NULL,
    [AccountType]       VARCHAR (10)     NOT NULL,
    [IsEnabled]         BIT              NOT NULL,
    [EmployeeIdRaw]     VARCHAR (20)     NULL,
    [EmployeeIdNumber]  INT              NULL,
    [GroupNames]        NVARCHAR (4000)  NULL,
    [LastStagedBatchId] BIGINT           NOT NULL,
    [CreatedAtUtc]      DATETIME2 (3)    CONSTRAINT [DF_staging_DirectoryAccount_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]      DATETIME2 (3)    CONSTRAINT [DF_staging_DirectoryAccount_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_staging_DirectoryAccount] PRIMARY KEY CLUSTERED ([AccountGuid] ASC),
    CONSTRAINT [FK_staging_DirectoryAccount_LandingRow]
        FOREIGN KEY ([LandingRowId]) REFERENCES [landing].[DirectoryAccountRaw] ([LandingRowId]),
    CONSTRAINT [FK_staging_DirectoryAccount_LastStagedBatch]
        FOREIGN KEY ([LastStagedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId])
);
GO

CREATE NONCLUSTERED INDEX [IX_staging_DirectoryAccount_EmployeeIdNumber]
    ON [staging].[DirectoryAccount] ([EmployeeIdNumber] ASC)
    INCLUDE ([AccountType], [IsEnabled])
    WHERE ([EmployeeIdNumber] IS NOT NULL);
