CREATE TABLE [DirectorySim].[GroupMembership] (
    [GroupMembershipId] BIGINT           NOT NULL,
    [AccountGuid]       UNIQUEIDENTIFIER NOT NULL,
    [GroupName]         VARCHAR (128)    NOT NULL,
    [AddedAtUtc]        DATETIME2 (3)    NOT NULL,
    [CreatedAtUtc]      DATETIME2 (3)    CONSTRAINT [DF_DirectorySim_GroupMembership_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]      DATETIME2 (3)    CONSTRAINT [DF_DirectorySim_GroupMembership_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_DirectorySim_GroupMembership] PRIMARY KEY CLUSTERED ([GroupMembershipId] ASC),
    CONSTRAINT [FK_DirectorySim_GroupMembership_DirectoryAccount]
        FOREIGN KEY ([AccountGuid]) REFERENCES [DirectorySim].[DirectoryAccount] ([AccountGuid]),
    CONSTRAINT [UQ_DirectorySim_GroupMembership_AccountGroup] UNIQUE ([AccountGuid], [GroupName])
);
