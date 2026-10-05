CREATE TABLE [SlateSim].[Address] (
    [AddressId]    BIGINT           NOT NULL,
    [PersonId]     UNIQUEIDENTIFIER NOT NULL,
    [AddressType]  VARCHAR (10)     NOT NULL,
    [Line1]        NVARCHAR (200)   NULL,
    [Line2]        NVARCHAR (200)   NULL,
    [City]         NVARCHAR (100)   NULL,
    [StateCode]    CHAR (2)         NULL,
    [PostalCode]   VARCHAR (10)     NULL,
    [CountryCode]  CHAR (2)         CONSTRAINT [DF_SlateSim_Address_CountryCode] DEFAULT ('US') NOT NULL,
    [IsPrimary]    BIT              CONSTRAINT [DF_SlateSim_Address_IsPrimary] DEFAULT (0) NOT NULL,
    [CreatedAtUtc] DATETIME2 (3)    CONSTRAINT [DF_SlateSim_Address_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc] DATETIME2 (3)    CONSTRAINT [DF_SlateSim_Address_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_SlateSim_Address] PRIMARY KEY CLUSTERED ([AddressId] ASC),
    CONSTRAINT [FK_SlateSim_Address_Person] FOREIGN KEY ([PersonId]) REFERENCES [SlateSim].[Person] ([PersonId]),
    CONSTRAINT [CK_SlateSim_Address_AddressType] CHECK (([AddressType] = 'HOME' OR [AddressType] = 'MAILING'))
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_SlateSim_Address_OnePrimaryPerPerson]
    ON [SlateSim].[Address] ([PersonId] ASC)
    WHERE ([IsPrimary] = 1);
GO

CREATE NONCLUSTERED INDEX [IX_SlateSim_Address_PersonId]
    ON [SlateSim].[Address] ([PersonId] ASC);
