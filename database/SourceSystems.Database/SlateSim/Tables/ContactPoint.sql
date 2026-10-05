-- ContactValue is stored as entered; malformed emails are possible by design and are
-- detected by CampusDataOps validation rather than rejected at the CRM.
CREATE TABLE [SlateSim].[ContactPoint] (
    [ContactPointId] BIGINT           NOT NULL,
    [PersonId]       UNIQUEIDENTIFIER NOT NULL,
    [ContactType]    VARCHAR (10)     NOT NULL,
    [ContactValue]   NVARCHAR (320)   NOT NULL,
    [IsPrimary]      BIT              CONSTRAINT [DF_SlateSim_ContactPoint_IsPrimary] DEFAULT (0) NOT NULL,
    [CreatedAtUtc]   DATETIME2 (3)    CONSTRAINT [DF_SlateSim_ContactPoint_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]   DATETIME2 (3)    CONSTRAINT [DF_SlateSim_ContactPoint_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_SlateSim_ContactPoint] PRIMARY KEY CLUSTERED ([ContactPointId] ASC),
    CONSTRAINT [FK_SlateSim_ContactPoint_Person] FOREIGN KEY ([PersonId]) REFERENCES [SlateSim].[Person] ([PersonId]),
    CONSTRAINT [CK_SlateSim_ContactPoint_ContactType] CHECK (([ContactType] = 'EMAIL' OR [ContactType] = 'PHONE'))
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_SlateSim_ContactPoint_OnePrimaryPerType]
    ON [SlateSim].[ContactPoint] ([PersonId] ASC, [ContactType] ASC)
    WHERE ([IsPrimary] = 1);
