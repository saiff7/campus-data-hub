CREATE TABLE [reference].[BatchStatus] (
    [BatchStatusCode] VARCHAR (20)   NOT NULL,
    [Description]     NVARCHAR (200) NOT NULL,
    [IsTerminal]      BIT            NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_reference_BatchStatus_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3)  CONSTRAINT [DF_reference_BatchStatus_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_BatchStatus] PRIMARY KEY CLUSTERED ([BatchStatusCode] ASC)
);
