-- Governed extract run status codes (docs/specifications/extract-controls.md).
CREATE TABLE [reference].[ExtractStatus] (
    [ExtractStatusCode]  VARCHAR (15)   NOT NULL,
    [Description]        NVARCHAR (200) NOT NULL,
    [CreatedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_reference_ExtractStatus_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_reference_ExtractStatus_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ExtractStatus] PRIMARY KEY CLUSTERED ([ExtractStatusCode] ASC)
);
