-- Allowed exception status changes. integration.ExceptionAction references this table, so a
-- transition that is not listed here cannot be recorded.
CREATE TABLE [reference].[ExceptionStatusTransition] (
    [FromStatusCode] VARCHAR (30)   NOT NULL,
    [ToStatusCode]   VARCHAR (30)   NOT NULL,
    [Description]    NVARCHAR (400) NOT NULL,
    [CreatedAtUtc]   DATETIME2 (3)  CONSTRAINT [DF_reference_ExceptionStatusTransition_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]   DATETIME2 (3)  CONSTRAINT [DF_reference_ExceptionStatusTransition_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ExceptionStatusTransition] PRIMARY KEY CLUSTERED ([FromStatusCode] ASC, [ToStatusCode] ASC),
    CONSTRAINT [FK_reference_ExceptionStatusTransition_From]
        FOREIGN KEY ([FromStatusCode]) REFERENCES [reference].[ExceptionStatus] ([ExceptionStatusCode]),
    CONSTRAINT [FK_reference_ExceptionStatusTransition_To]
        FOREIGN KEY ([ToStatusCode]) REFERENCES [reference].[ExceptionStatus] ([ExceptionStatusCode]),
    CONSTRAINT [CK_reference_ExceptionStatusTransition_Changes] CHECK ([FromStatusCode] <> [ToStatusCode])
);
