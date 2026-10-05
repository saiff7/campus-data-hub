-- SIS person keyed by the 7-digit institutional ID. Unlike the CRM, the SIS enforces
-- required legal name and birth date and a basic email shape. It does not prevent two
-- records for the same human; duplicate detection is a CampusDataOps responsibility.
CREATE TABLE [J1Sim].[Person] (
    [IdNumber]     INT            NOT NULL,
    [FirstName]    NVARCHAR (100) NOT NULL,
    [MiddleName]   NVARCHAR (100) NULL,
    [LastName]     NVARCHAR (100) NOT NULL,
    [BirthDate]    DATE           NOT NULL,
    [Email]        NVARCHAR (320) NULL,
    [Phone]        VARCHAR (20)   NULL,
    [AddressLine1] NVARCHAR (200) NULL,
    [City]         NVARCHAR (100) NULL,
    [StateCode]    CHAR (2)       NULL,
    [PostalCode]   VARCHAR (10)   NULL,
    [CreatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_J1Sim_Person_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_J1Sim_Person_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_Person] PRIMARY KEY CLUSTERED ([IdNumber] ASC),
    CONSTRAINT [CK_J1Sim_Person_IdNumberRange] CHECK (([IdNumber] >= 1000000 AND [IdNumber] <= 9999999)),
    CONSTRAINT [CK_J1Sim_Person_EmailShape] CHECK ([Email] IS NULL OR [Email] LIKE '_%@_%._%'),
    CONSTRAINT [CK_J1Sim_Person_UpdatedAfterCreated] CHECK ([UpdatedAtUtc] >= [CreatedAtUtc])
);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_Person_UpdatedAtUtc]
    ON [J1Sim].[Person] ([UpdatedAtUtc] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_Person_NameBirthDate]
    ON [J1Sim].[Person] ([LastName] ASC, [FirstName] ASC, [BirthDate] ASC);
