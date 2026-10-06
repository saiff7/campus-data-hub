-- Integration exception lifecycle states. IsActiveState = 1 for states in which a repeat of
-- the same condition updates the existing exception instead of creating a new one.
CREATE TABLE [reference].[ExceptionStatus] (
    [ExceptionStatusCode] VARCHAR (30)   NOT NULL,
    [Description]         NVARCHAR (400) NOT NULL,
    [IsActiveState]       BIT            NOT NULL,
    [SortOrder]           TINYINT        NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_ExceptionStatus_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_ExceptionStatus_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ExceptionStatus] PRIMARY KEY CLUSTERED ([ExceptionStatusCode] ASC),
    CONSTRAINT [UQ_reference_ExceptionStatus_SortOrder] UNIQUE ([SortOrder])
);
