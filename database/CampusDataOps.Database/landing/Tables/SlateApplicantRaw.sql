-- One row per Slate-Sim person per version received. Values are exactly as extracted;
-- standardization happens in staging.
-- Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest
-- landed version of the same key; one version per key per batch is database-enforced.
CREATE TABLE [landing].[SlateApplicantRaw] (
    [LandingRowId]       BIGINT            IDENTITY (1, 1) NOT NULL,
    [BatchId]            BIGINT            NOT NULL,
    [SourceSystemCode]   VARCHAR (20)      NOT NULL
        CONSTRAINT [DF_landing_SlateApplicantRaw_SourceSystemCode] DEFAULT ('SLATE_SIM'),
    [PersonId]           UNIQUEIDENTIFIER  NOT NULL,
    [FirstName]          NVARCHAR (100)    NULL,
    [MiddleName]         NVARCHAR (100)    NULL,
    [LastName]           NVARCHAR (100)    NULL,
    [PreferredName]      NVARCHAR (100)    NULL,
    [BirthDate]          DATE              NULL,
    [Email]              NVARCHAR (320)    NULL,
    [Phone]              NVARCHAR (320)    NULL,
    [AddressLine1]       NVARCHAR (200)    NULL,
    [AddressLine2]       NVARCHAR (200)    NULL,
    [City]               NVARCHAR (100)    NULL,
    [StateCode]          CHAR (2)          NULL,
    [PostalCode]         VARCHAR (10)      NULL,
    [CountryCode]        CHAR (2)          NULL,
    [SisIdClaim]         VARCHAR (50)      NULL,
    [SourceRecordId]     AS (CONVERT(VARCHAR (64), [PersonId])) PERSISTED NOT NULL,
    [SourceUpdatedAtUtc] DATETIME2 (3)     NOT NULL,
    [RecordHash]         BINARY (32)       NOT NULL,
    [RequestId]          VARCHAR (100)     NOT NULL,
    [IngestedAtUtc]      DATETIME2 (3)     NOT NULL
        CONSTRAINT [DF_landing_SlateApplicantRaw_IngestedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_landing_SlateApplicantRaw] PRIMARY KEY CLUSTERED ([LandingRowId] ASC),
    CONSTRAINT [FK_landing_SlateApplicantRaw_BatchRun] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_landing_SlateApplicantRaw_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [CK_landing_SlateApplicantRaw_SourceSystemCode] CHECK ([SourceSystemCode] = 'SLATE_SIM')
);
GO

-- Serves the latest-version lookup (TOP 1 ... ORDER BY BatchId DESC) and enforces one
-- version per key per batch.
CREATE UNIQUE NONCLUSTERED INDEX [UX_landing_SlateApplicantRaw_KeyBatch]
    ON [landing].[SlateApplicantRaw] ([PersonId] ASC, [BatchId] DESC)
    INCLUDE ([RecordHash]);
GO

CREATE NONCLUSTERED INDEX [IX_landing_SlateApplicantRaw_BatchId]
    ON [landing].[SlateApplicantRaw] ([BatchId] ASC);
