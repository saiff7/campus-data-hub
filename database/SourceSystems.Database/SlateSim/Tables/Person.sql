-- Admissions CRM person. Slate-Sim accepts applicant-entered values as typed, so
-- birth date and middle name are optional and formats are not validated here.
CREATE TABLE [SlateSim].[Person] (
    [PersonId]      UNIQUEIDENTIFIER NOT NULL,
    [FirstName]     NVARCHAR (100)   NULL,
    [MiddleName]    NVARCHAR (100)   NULL,
    [LastName]      NVARCHAR (100)   NULL,
    [PreferredName] NVARCHAR (100)   NULL,
    [BirthDate]     DATE             NULL,
    [CreatedAtUtc]  DATETIME2 (3)    CONSTRAINT [DF_SlateSim_Person_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]  DATETIME2 (3)    CONSTRAINT [DF_SlateSim_Person_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_SlateSim_Person] PRIMARY KEY CLUSTERED ([PersonId] ASC),
    CONSTRAINT [CK_SlateSim_Person_UpdatedAfterCreated] CHECK ([UpdatedAtUtc] >= [CreatedAtUtc])
);
GO

CREATE NONCLUSTERED INDEX [IX_SlateSim_Person_UpdatedAtUtc]
    ON [SlateSim].[Person] ([UpdatedAtUtc] ASC);
