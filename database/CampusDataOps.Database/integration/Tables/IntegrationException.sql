-- Managed exceptions for the applicant workflow (docs/specifications/integration-controls.md).
-- An exception is about an application (ApplicationId) or a whole batch (SubjectBatchId).
-- One active exception per subject and reason is enforced by the filtered unique index; a
-- repeat updates LastSeenBatchId and OccurrenceCount. SourceHash is the staged application
-- version when the exception was last seen: a CLOSED exception keeps holding its condition
-- back only while the application is unchanged, so an analyst's closure is not re-raised
-- every night.
CREATE TABLE [integration].[IntegrationException] (
    [ExceptionId]         BIGINT           IDENTITY (1, 1) NOT NULL,
    [ExceptionReasonCode] VARCHAR (40)     NOT NULL,
    [SourceSystemCode]    VARCHAR (20)     NOT NULL,
    [ApplicationId]       UNIQUEIDENTIFIER NULL,
    [SubjectBatchId]      BIGINT           NULL,
    [ExceptionStatusCode] VARCHAR (30)     NOT NULL,
    [Severity]            VARCHAR (10)     NOT NULL,
    [AssignedTo]          NVARCHAR (128)   NULL,
    [DetailCode]          VARCHAR (200)    NULL,
    [SourceHash]          BINARY (32)      NULL,
    [FirstSeenBatchId]    BIGINT           NOT NULL,
    [LastSeenBatchId]     BIGINT           NOT NULL,
    [OccurrenceCount]     INT              NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)    CONSTRAINT [DF_integration_IntegrationException_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)    CONSTRAINT [DF_integration_IntegrationException_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [RowVersion]          ROWVERSION       NOT NULL,
    CONSTRAINT [PK_integration_IntegrationException] PRIMARY KEY CLUSTERED ([ExceptionId] ASC),
    CONSTRAINT [FK_integration_IntegrationException_Reason]
        FOREIGN KEY ([ExceptionReasonCode]) REFERENCES [reference].[ExceptionReason] ([ExceptionReasonCode]),
    CONSTRAINT [FK_integration_IntegrationException_SourceSystem]
        FOREIGN KEY ([SourceSystemCode]) REFERENCES [reference].[SourceSystem] ([SourceSystemCode]),
    CONSTRAINT [FK_integration_IntegrationException_Status]
        FOREIGN KEY ([ExceptionStatusCode]) REFERENCES [reference].[ExceptionStatus] ([ExceptionStatusCode]),
    CONSTRAINT [FK_integration_IntegrationException_SubjectBatch]
        FOREIGN KEY ([SubjectBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_integration_IntegrationException_FirstSeenBatch]
        FOREIGN KEY ([FirstSeenBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_integration_IntegrationException_LastSeenBatch]
        FOREIGN KEY ([LastSeenBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [CK_integration_IntegrationException_OneSubject]
        CHECK (([ApplicationId] IS NOT NULL AND [SubjectBatchId] IS NULL) OR ([ApplicationId] IS NULL AND [SubjectBatchId] IS NOT NULL)),
    CONSTRAINT [CK_integration_IntegrationException_Severity]
        CHECK (([Severity] = 'HIGH' OR [Severity] = 'MEDIUM' OR [Severity] = 'LOW')),
    CONSTRAINT [CK_integration_IntegrationException_AssignedHasOwner]
        CHECK ([ExceptionStatusCode] <> 'ASSIGNED' OR [AssignedTo] IS NOT NULL),
    CONSTRAINT [CK_integration_IntegrationException_OccurrenceCount] CHECK ([OccurrenceCount] >= 1)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_integration_IntegrationException_OneActivePerSubjectReason]
    ON [integration].[IntegrationException] ([ExceptionReasonCode] ASC, [ApplicationId] ASC, [SubjectBatchId] ASC)
    WHERE ([ExceptionStatusCode] <> 'REPROCESSED' AND [ExceptionStatusCode] <> 'CLOSED');
GO

CREATE NONCLUSTERED INDEX [IX_integration_IntegrationException_Application]
    ON [integration].[IntegrationException] ([ApplicationId] ASC, [ExceptionStatusCode] ASC)
    INCLUDE ([ExceptionReasonCode], [SourceHash])
    WHERE ([ApplicationId] IS NOT NULL);
GO

CREATE NONCLUSTERED INDEX [IX_integration_IntegrationException_Status]
    ON [integration].[IntegrationException] ([ExceptionStatusCode] ASC, [CreatedAtUtc] ASC)
    INCLUDE ([ExceptionReasonCode], [Severity], [AssignedTo]);
