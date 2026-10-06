-- Current standardized state of each J1-Sim person and student record. Matching compares the
-- stored normalized columns, which the two filtered indexes below support.
CREATE TABLE [staging].[Person] (
    [IdNumber]             INT            NOT NULL,
    [LandingRowId]         BIGINT         NOT NULL,
    [FirstNameRaw]         NVARCHAR (100) NOT NULL,
    [FirstNameStd]         NVARCHAR (100) NULL,
    [MiddleNameRaw]        NVARCHAR (100) NULL,
    [LastNameRaw]          NVARCHAR (100) NOT NULL,
    [LastNameStd]          NVARCHAR (100) NULL,
    [BirthDate]            DATE           NOT NULL,
    [EmailRaw]             NVARCHAR (320) NULL,
    [EmailStd]             NVARCHAR (320) NULL,
    [PhoneRaw]             VARCHAR (20)   NULL,
    [PhoneStd]             VARCHAR (10)   NULL,
    [AddressLine1]         NVARCHAR (200) NULL,
    [City]                 NVARCHAR (100) NULL,
    [StateCode]            CHAR (2)       NULL,
    [PostalCodeRaw]        VARCHAR (10)   NULL,
    [PostalCode5]          CHAR (5)       NULL,
    [HasStudentRecord]     BIT            NOT NULL,
    [StudentProgramCode]   VARCHAR (20)   NULL,
    [StudentEntryTermCode] VARCHAR (10)   NULL,
    [StudentStatus]        VARCHAR (20)   NULL,
    [ResidencyCode]        VARCHAR (20)   NULL,
    [MatriculationDate]    DATE           NULL,
    [LastStagedBatchId]    BIGINT         NOT NULL,
    [CreatedAtUtc]         DATETIME2 (3)  CONSTRAINT [DF_staging_Person_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]         DATETIME2 (3)  CONSTRAINT [DF_staging_Person_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_staging_Person] PRIMARY KEY CLUSTERED ([IdNumber] ASC),
    CONSTRAINT [FK_staging_Person_LandingRow] FOREIGN KEY ([LandingRowId]) REFERENCES [landing].[J1PersonRaw] ([LandingRowId]),
    CONSTRAINT [FK_staging_Person_LastStagedBatch] FOREIGN KEY ([LastStagedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [CK_staging_Person_StudentRecord]
        CHECK (([HasStudentRecord] = 1 AND [StudentStatus] IS NOT NULL) OR ([HasStudentRecord] = 0 AND [StudentStatus] IS NULL))
);
GO

CREATE NONCLUSTERED INDEX [IX_staging_Person_EmailBirthDate]
    ON [staging].[Person] ([EmailStd] ASC, [BirthDate] ASC)
    WHERE ([EmailStd] IS NOT NULL);
GO

CREATE NONCLUSTERED INDEX [IX_staging_Person_NameBirthDatePostal]
    ON [staging].[Person] ([LastNameStd] ASC, [FirstNameStd] ASC, [BirthDate] ASC, [PostalCode5] ASC)
    WHERE ([PostalCode5] IS NOT NULL);
