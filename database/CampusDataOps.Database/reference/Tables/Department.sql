-- Administrative offices that own reports, measures, extracts and data-quality rules.
-- DepartmentName equals the OwnerDepartment text used by dq.Rule and reference.ExceptionReason.
CREATE TABLE [reference].[Department] (
    [DepartmentCode] VARCHAR (30)   NOT NULL,
    [DepartmentName] NVARCHAR (100) NOT NULL,
    [CreatedAtUtc]   DATETIME2 (3)  CONSTRAINT [DF_reference_Department_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]   DATETIME2 (3)  CONSTRAINT [DF_reference_Department_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_Department] PRIMARY KEY CLUSTERED ([DepartmentCode] ASC),
    CONSTRAINT [UQ_reference_Department_DepartmentName] UNIQUE ([DepartmentName])
);
