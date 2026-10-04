CREATE TABLE [reference].[ExceptionReason] (
    [ExceptionReasonCode] VARCHAR (40)   NOT NULL,
    [Description]         NVARCHAR (400) NOT NULL,
    [Category]            VARCHAR (20)   NOT NULL,
    [DefaultSeverity]     VARCHAR (10)   NOT NULL,
    [OwnerDepartment]     NVARCHAR (100) NOT NULL,
    [BlocksProcessing]    BIT            NOT NULL,
    [RemediationGuidance] NVARCHAR (800) NOT NULL,
    [IsActive]            BIT            NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_ExceptionReason_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_ExceptionReason_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_ExceptionReason] PRIMARY KEY CLUSTERED ([ExceptionReasonCode] ASC),
    CONSTRAINT [CK_reference_ExceptionReason_Category]
        CHECK (([Category] = 'IDENTITY' OR [Category] = 'VALIDATION' OR [Category] = 'REFERENCE' OR [Category] = 'PROCESSING' OR [Category] = 'RECONCILIATION')),
    CONSTRAINT [CK_reference_ExceptionReason_DefaultSeverity] CHECK (([DefaultSeverity] = 'HIGH' OR [DefaultSeverity] = 'MEDIUM' OR [DefaultSeverity] = 'LOW'))
);
