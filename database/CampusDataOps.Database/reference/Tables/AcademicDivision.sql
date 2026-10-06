-- Academic divisions that group programs, used for reporting and program-scoped access.
CREATE TABLE [reference].[AcademicDivision] (
    [DivisionCode] VARCHAR (30)   NOT NULL,
    [DivisionName] NVARCHAR (100) NOT NULL,
    [CreatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_reference_AcademicDivision_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_reference_AcademicDivision_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_AcademicDivision] PRIMARY KEY CLUSTERED ([DivisionCode] ASC),
    CONSTRAINT [UQ_reference_AcademicDivision_DivisionName] UNIQUE ([DivisionName])
);
