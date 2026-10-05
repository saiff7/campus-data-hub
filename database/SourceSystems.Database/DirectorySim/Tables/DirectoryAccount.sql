-- EmployeeId carries the J1-Sim IdNumber as text, as directory attributes usually do.
-- It is not a foreign key across systems, so orphan accounts can exist.
CREATE TABLE [DirectorySim].[DirectoryAccount] (
    [AccountGuid]       UNIQUEIDENTIFIER NOT NULL,
    [SamAccountName]    VARCHAR (64)     NOT NULL,
    [UserPrincipalName] NVARCHAR (256)   NOT NULL,
    [EmployeeId]        VARCHAR (20)     NULL,
    [DisplayName]       NVARCHAR (200)   NOT NULL,
    [AccountType]       VARCHAR (10)     NOT NULL,
    [IsEnabled]         BIT              NOT NULL,
    [WhenCreatedUtc]    DATETIME2 (3)    NOT NULL,
    [CreatedAtUtc]      DATETIME2 (3)    CONSTRAINT [DF_DirectorySim_DirectoryAccount_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]      DATETIME2 (3)    CONSTRAINT [DF_DirectorySim_DirectoryAccount_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_DirectorySim_DirectoryAccount] PRIMARY KEY CLUSTERED ([AccountGuid] ASC),
    CONSTRAINT [UQ_DirectorySim_DirectoryAccount_SamAccountName] UNIQUE ([SamAccountName]),
    CONSTRAINT [UQ_DirectorySim_DirectoryAccount_UserPrincipalName] UNIQUE ([UserPrincipalName]),
    CONSTRAINT [CK_DirectorySim_DirectoryAccount_AccountType]
        CHECK (([AccountType] = 'STUDENT' OR [AccountType] = 'STAFF' OR [AccountType] = 'SERVICE')),
    CONSTRAINT [CK_DirectorySim_DirectoryAccount_UpdatedAfterCreated] CHECK ([UpdatedAtUtc] >= [CreatedAtUtc])
);
GO

CREATE NONCLUSTERED INDEX [IX_DirectorySim_DirectoryAccount_EmployeeId]
    ON [DirectorySim].[DirectoryAccount] ([EmployeeId] ASC)
    WHERE ([EmployeeId] IS NOT NULL);
GO

CREATE NONCLUSTERED INDEX [IX_DirectorySim_DirectoryAccount_UpdatedAtUtc]
    ON [DirectorySim].[DirectoryAccount] ([UpdatedAtUtc] ASC);
