-- IdentifierValue is intentionally not globally unique: two CRM people can claim the
-- same SIS ID, which integration must treat as an identity conflict.
CREATE TABLE [SlateSim].[ExternalIdentifier] (
    [ExternalIdentifierId] BIGINT           NOT NULL,
    [PersonId]             UNIQUEIDENTIFIER NOT NULL,
    [IdentifierType]       VARCHAR (20)     NOT NULL,
    [IdentifierValue]      VARCHAR (50)     NOT NULL,
    [CreatedAtUtc]         DATETIME2 (3)    CONSTRAINT [DF_SlateSim_ExternalIdentifier_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]         DATETIME2 (3)    CONSTRAINT [DF_SlateSim_ExternalIdentifier_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_SlateSim_ExternalIdentifier] PRIMARY KEY CLUSTERED ([ExternalIdentifierId] ASC),
    CONSTRAINT [FK_SlateSim_ExternalIdentifier_Person] FOREIGN KEY ([PersonId]) REFERENCES [SlateSim].[Person] ([PersonId]),
    CONSTRAINT [CK_SlateSim_ExternalIdentifier_IdentifierType] CHECK (([IdentifierType] = 'SIS_ID' OR [IdentifierType] = 'COMMON_APP_ID')),
    CONSTRAINT [UQ_SlateSim_ExternalIdentifier_PersonType] UNIQUE ([PersonId], [IdentifierType])
);
GO

CREATE NONCLUSTERED INDEX [IX_SlateSim_ExternalIdentifier_TypeValue]
    ON [SlateSim].[ExternalIdentifier] ([IdentifierType] ASC, [IdentifierValue] ASC);
