-- Current standardized state of each Slate-Sim application, with the applicant's person
-- values. Raw values sit beside standardized ones; nothing is corrected silently. Validation
-- columns describe the problem with codes; integration.usp_CreateIntegrationExceptions turns
-- them into exceptions. SourceHash changes only when the landed source values change, and is
-- what matching uses to decide whether an application needs a new decision.
-- Validity flags are NULL when the raw value is absent or blank, 1 when it standardizes and
-- 0 when it is present but invalid.
CREATE TABLE [staging].[Applicant] (
    [ApplicationId]             UNIQUEIDENTIFIER NOT NULL,
    [SlatePersonId]             UNIQUEIDENTIFIER NOT NULL,
    [ApplicantLandingRowId]     BIGINT           NOT NULL,
    [ApplicationLandingRowId]   BIGINT           NOT NULL,
    [SourceHash]                BINARY (32)      NOT NULL,
    [ApplicationStatus]         VARCHAR (20)     NOT NULL,
    [StudentType]               VARCHAR (20)     NOT NULL,
    [ExportQueuedAtUtc]         DATETIME2 (3)    NULL,
    [IsEligible]                BIT              NOT NULL,
    [FirstNameRaw]              NVARCHAR (100)   NULL,
    [FirstNameStd]              NVARCHAR (100)   NULL,
    [MiddleNameRaw]             NVARCHAR (100)   NULL,
    [MiddleNameStd]             NVARCHAR (100)   NULL,
    [LastNameRaw]               NVARCHAR (100)   NULL,
    [LastNameStd]               NVARCHAR (100)   NULL,
    [BirthDate]                 DATE             NULL,
    [EmailRaw]                  NVARCHAR (320)   NULL,
    [EmailStd]                  NVARCHAR (320)   NULL,
    [IsEmailValid]              BIT              NULL,
    [PhoneRaw]                  NVARCHAR (320)   NULL,
    [PhoneStd]                  VARCHAR (10)     NULL,
    [IsPhoneValid]              BIT              NULL,
    [AddressLine1]              NVARCHAR (200)   NULL,
    [City]                      NVARCHAR (100)   NULL,
    [StateCode]                 CHAR (2)         NULL,
    [CountryCode]               CHAR (2)         NULL,
    [PostalCodeRaw]             VARCHAR (10)     NULL,
    [PostalCode5]               CHAR (5)         NULL,
    [ResidencyCode]             VARCHAR (20)     NOT NULL,
    [SisIdClaimRaw]             VARCHAR (50)     NULL,
    [SisIdClaim]                INT              NULL,
    [IsSisIdClaimValid]         BIT              NULL,
    [EntryTermCodeRaw]          VARCHAR (10)     NULL,
    [EntryTermCode]             VARCHAR (10)     NULL,
    [TermValidationCode]        VARCHAR (20)     NULL,
    [ProgramChoice1Raw]         VARCHAR (20)     NULL,
    [J1ProgramCode]             VARCHAR (20)     NULL,
    [ProgramValidationCode]     VARCHAR (20)     NULL,
    [MissingRequiredFields]     VARCHAR (100)    NULL,
    [DuplicateApplicationCount] INT              NOT NULL,
    [FirstStagedBatchId]        BIGINT           NOT NULL,
    [LastStagedBatchId]         BIGINT           NOT NULL,
    [CreatedAtUtc]              DATETIME2 (3)    CONSTRAINT [DF_staging_Applicant_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]              DATETIME2 (3)    CONSTRAINT [DF_staging_Applicant_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_staging_Applicant] PRIMARY KEY CLUSTERED ([ApplicationId] ASC),
    CONSTRAINT [FK_staging_Applicant_ApplicantLandingRow]
        FOREIGN KEY ([ApplicantLandingRowId]) REFERENCES [landing].[SlateApplicantRaw] ([LandingRowId]),
    CONSTRAINT [FK_staging_Applicant_ApplicationLandingRow]
        FOREIGN KEY ([ApplicationLandingRowId]) REFERENCES [landing].[SlateApplicationRaw] ([LandingRowId]),
    CONSTRAINT [FK_staging_Applicant_FirstStagedBatch] FOREIGN KEY ([FirstStagedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_staging_Applicant_LastStagedBatch] FOREIGN KEY ([LastStagedBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_staging_Applicant_EntryTerm] FOREIGN KEY ([EntryTermCode]) REFERENCES [reference].[AcademicTerm] ([TermCode]),
    CONSTRAINT [CK_staging_Applicant_EmailValidity]
        CHECK (([IsEmailValid] IS NULL AND [EmailStd] IS NULL)
            OR ([IsEmailValid] = 1 AND [EmailStd] IS NOT NULL)
            OR ([IsEmailValid] = 0 AND [EmailStd] IS NULL AND [EmailRaw] IS NOT NULL)),
    CONSTRAINT [CK_staging_Applicant_PhoneValidity]
        CHECK (([IsPhoneValid] IS NULL AND [PhoneStd] IS NULL)
            OR ([IsPhoneValid] = 1 AND [PhoneStd] IS NOT NULL)
            OR ([IsPhoneValid] = 0 AND [PhoneStd] IS NULL AND [PhoneRaw] IS NOT NULL)),
    CONSTRAINT [CK_staging_Applicant_SisIdValidity]
        CHECK (([IsSisIdClaimValid] IS NULL AND [SisIdClaim] IS NULL)
            OR ([IsSisIdClaimValid] = 1 AND [SisIdClaim] IS NOT NULL)
            OR ([IsSisIdClaimValid] = 0 AND [SisIdClaim] IS NULL AND [SisIdClaimRaw] IS NOT NULL)),
    CONSTRAINT [CK_staging_Applicant_TermValidation]
        CHECK (([TermValidationCode] IS NULL AND [EntryTermCode] IS NOT NULL)
            OR (([TermValidationCode] = 'MISSING' OR [TermValidationCode] = 'UNKNOWN_TERM' OR [TermValidationCode] = 'CLOSED_TERM')
                AND [EntryTermCode] IS NULL)),
    CONSTRAINT [CK_staging_Applicant_ProgramValidation]
        CHECK (([ProgramValidationCode] IS NULL AND [J1ProgramCode] IS NOT NULL)
            OR (([ProgramValidationCode] = 'MISSING' OR [ProgramValidationCode] = 'NOT_IN_CROSSWALK'
                    OR [ProgramValidationCode] = 'INACTIVE')
                AND [J1ProgramCode] IS NULL)),
    CONSTRAINT [CK_staging_Applicant_ResidencyCode]
        CHECK (([ResidencyCode] = 'IN_STATE' OR [ResidencyCode] = 'OUT_OF_STATE' OR [ResidencyCode] = 'INTERNATIONAL')),
    CONSTRAINT [CK_staging_Applicant_DuplicateApplicationCount] CHECK ([DuplicateApplicationCount] >= 1)
);
GO

CREATE NONCLUSTERED INDEX [IX_staging_Applicant_SlatePersonId]
    ON [staging].[Applicant] ([SlatePersonId] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_staging_Applicant_Eligible]
    ON [staging].[Applicant] ([IsEligible] ASC)
    INCLUDE ([SlatePersonId], [SourceHash]);
