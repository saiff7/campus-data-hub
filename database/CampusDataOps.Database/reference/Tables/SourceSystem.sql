CREATE TABLE [reference].[SourceSystem] (
    [SourceSystemCode] VARCHAR (20)   NOT NULL,
    [SourceSystemName] NVARCHAR (100) NOT NULL,
    [Description]      NVARCHAR (400) NOT NULL,
    [IsActive]         BIT            NOT NULL,
    [CreatedAtUtc]     DATETIME2 (3)  CONSTRAINT [DF_reference_SourceSystem_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]     DATETIME2 (3)  CONSTRAINT [DF_reference_SourceSystem_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_SourceSystem] PRIMARY KEY CLUSTERED ([SourceSystemCode] ASC),
    CONSTRAINT [UQ_reference_SourceSystem_SourceSystemName] UNIQUE ([SourceSystemName]),
    CONSTRAINT [CK_reference_SourceSystem_Code] CHECK ([SourceSystemCode] NOT LIKE '%[^A-Z0-9_]%')
);
