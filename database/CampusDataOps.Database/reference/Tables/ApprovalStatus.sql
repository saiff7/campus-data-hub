-- Governed extract approval status codes (docs/specifications/extract-controls.md).
CREATE TABLE [reference].[ApprovalStatus] (
    [ApprovalStatusCode]  VARCHAR (15)   NOT NULL,
    [Description]         NVARCHAR (200) NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_ApprovalStatus_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_ApprovalStatus_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ApprovalStatus] PRIMARY KEY CLUSTERED ([ApprovalStatusCode] ASC)
);
