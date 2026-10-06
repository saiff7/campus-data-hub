-- Governed extract validation status codes (docs/specifications/extract-controls.md).
CREATE TABLE [reference].[ValidationStatus] (
    [ValidationStatusCode]  VARCHAR (15)   NOT NULL,
    [Description]           NVARCHAR (200) NOT NULL,
    [CreatedAtUtc]          DATETIME2 (3)  CONSTRAINT [DF_reference_ValidationStatus_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]          DATETIME2 (3)  CONSTRAINT [DF_reference_ValidationStatus_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ValidationStatus] PRIMARY KEY CLUSTERED ([ValidationStatusCode] ASC)
);
