CREATE TABLE [reference].[BatchStepStatus] (
    [BatchStepStatusCode] VARCHAR (20)   NOT NULL,
    [Description]         NVARCHAR (200) NOT NULL,
    [IsTerminal]          BIT            NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_BatchStepStatus_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_BatchStepStatus_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_BatchStepStatus] PRIMARY KEY CLUSTERED ([BatchStepStatusCode] ASC)
);
