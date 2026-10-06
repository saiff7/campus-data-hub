-- One recorded, checked run of an extract (docs/specifications/extract-controls.md). After a run
-- leaves GENERATING only its approval fields may change (trigger below). The CHECK constraints
-- name every IS NOT NULL explicitly, because a CHECK passes when its condition is UNKNOWN.
CREATE TABLE [compliance].[ExtractRun] (
    [ExtractRunId]         BIGINT          IDENTITY (1, 1) NOT NULL,
    [ExtractTypeCode]      VARCHAR (30)    NOT NULL,
    [ReportingPeriod]      VARCHAR (20)    NOT NULL,
    [PeriodStartDate]      DATE            NOT NULL,
    [ParametersJson]       NVARCHAR (1000) NOT NULL,
    [SourceBatchId]        BIGINT          NOT NULL,
    [CensusSnapshotId]     INT             NULL,
    [ExtractStatusCode]    VARCHAR (15)    NOT NULL,
    [ValidationStatusCode] VARCHAR (15)    NULL,
    [ApprovalStatusCode]   VARCHAR (15)    CONSTRAINT [DF_compliance_ExtractRun_ApprovalStatusCode] DEFAULT ('PENDING') NOT NULL,
    [LineCount]            INT             NULL,
    [DataRowCount]         INT             NULL,
    [ContentSha256]        BINARY (32)     NULL,
    [GeneratorVersion]     VARCHAR (10)    NOT NULL,
    [RequestedBy]          NVARCHAR (128)  CONSTRAINT [DF_compliance_ExtractRun_RequestedBy] DEFAULT (USER_NAME()) NOT NULL,
    [RequestedByLogin]     NVARCHAR (128)  CONSTRAINT [DF_compliance_ExtractRun_RequestedByLogin] DEFAULT (ORIGINAL_LOGIN()) NOT NULL,
    [GeneratedAtUtc]       DATETIME2 (3)   CONSTRAINT [DF_compliance_ExtractRun_GeneratedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [CompletedAtUtc]       DATETIME2 (3)   NULL,
    [ErrorMessage]         NVARCHAR (2048) NULL,
    [ApprovedBy]           NVARCHAR (128)  NULL,
    [ApprovedAtUtc]        DATETIME2 (3)   NULL,
    [ApprovalNote]         NVARCHAR (400)  NULL,
    CONSTRAINT [PK_compliance_ExtractRun] PRIMARY KEY CLUSTERED ([ExtractRunId] ASC),
    CONSTRAINT [FK_compliance_ExtractRun_ExtractType]
        FOREIGN KEY ([ExtractTypeCode]) REFERENCES [reference].[ExtractType] ([ExtractTypeCode]),
    CONSTRAINT [FK_compliance_ExtractRun_SourceBatch] FOREIGN KEY ([SourceBatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_compliance_ExtractRun_CensusSnapshot]
        FOREIGN KEY ([CensusSnapshotId]) REFERENCES [compliance].[CensusSnapshot] ([CensusSnapshotId]),
    CONSTRAINT [FK_compliance_ExtractRun_ExtractStatus]
        FOREIGN KEY ([ExtractStatusCode]) REFERENCES [reference].[ExtractStatus] ([ExtractStatusCode]),
    CONSTRAINT [FK_compliance_ExtractRun_ValidationStatus]
        FOREIGN KEY ([ValidationStatusCode]) REFERENCES [reference].[ValidationStatus] ([ValidationStatusCode]),
    CONSTRAINT [FK_compliance_ExtractRun_ApprovalStatus]
        FOREIGN KEY ([ApprovalStatusCode]) REFERENCES [reference].[ApprovalStatus] ([ApprovalStatusCode]),
    CONSTRAINT [CK_compliance_ExtractRun_Succeeded]
        CHECK ([ExtractStatusCode] <> 'SUCCEEDED'
            OR ([LineCount] IS NOT NULL AND [DataRowCount] IS NOT NULL AND [ContentSha256] IS NOT NULL
                AND [ValidationStatusCode] IS NOT NULL AND [CompletedAtUtc] IS NOT NULL AND [LineCount] = [DataRowCount] + 1)),
    CONSTRAINT [CK_compliance_ExtractRun_Approval]
        CHECK (([ApprovalStatusCode] = 'PENDING' AND [ApprovedBy] IS NULL AND [ApprovedAtUtc] IS NULL)
            OR ([ApprovalStatusCode] = 'REJECTED' AND [ApprovedBy] IS NOT NULL AND [ApprovedAtUtc] IS NOT NULL
                AND [ApprovedBy] <> [RequestedBy] AND [ExtractStatusCode] = 'SUCCEEDED')
            OR ([ApprovalStatusCode] = 'APPROVED' AND [ApprovedBy] IS NOT NULL AND [ApprovedAtUtc] IS NOT NULL
                AND [ApprovedBy] <> [RequestedBy] AND [ExtractStatusCode] = 'SUCCEEDED'
                AND [ValidationStatusCode] IS NOT NULL AND [ValidationStatusCode] <> 'FAILED'))
);
GO

CREATE NONCLUSTERED INDEX [IX_compliance_ExtractRun_TypePeriod]
    ON [compliance].[ExtractRun] ([ExtractTypeCode] ASC, [PeriodStartDate] ASC)
    INCLUDE ([ExtractStatusCode], [ReportingPeriod]);
GO

CREATE TRIGGER [compliance].[trg_ExtractRun_Immutable]
ON [compliance].[ExtractRun]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted AS d WHERE d.[ExtractStatusCode] <> 'GENERATING')
        THROW 52120, N'Completed extract runs cannot be deleted.', 1;

    IF EXISTS (
        SELECT 1
        FROM deleted AS d
        INNER JOIN inserted AS i ON d.[ExtractRunId] = i.[ExtractRunId]
        WHERE d.[ExtractStatusCode] <> 'GENERATING'
          AND EXISTS (
              SELECT
                  d.[ExtractTypeCode], d.[ReportingPeriod], d.[PeriodStartDate], d.[ParametersJson], d.[SourceBatchId],
                  d.[CensusSnapshotId], d.[ExtractStatusCode], d.[ValidationStatusCode], d.[LineCount], d.[DataRowCount],
                  d.[ContentSha256], d.[GeneratorVersion], d.[RequestedBy], d.[GeneratedAtUtc], d.[CompletedAtUtc],
                  d.[ErrorMessage]
              EXCEPT
              SELECT
                  i.[ExtractTypeCode], i.[ReportingPeriod], i.[PeriodStartDate], i.[ParametersJson], i.[SourceBatchId],
                  i.[CensusSnapshotId], i.[ExtractStatusCode], i.[ValidationStatusCode], i.[LineCount], i.[DataRowCount],
                  i.[ContentSha256], i.[GeneratorVersion], i.[RequestedBy], i.[GeneratedAtUtc], i.[CompletedAtUtc],
                  i.[ErrorMessage]
          )
    )
        THROW 52121, N'Only the approval fields of a completed extract run may change.', 1;

    IF EXISTS (
        SELECT 1
        FROM deleted AS d
        INNER JOIN inserted AS i ON d.[ExtractRunId] = i.[ExtractRunId]
        WHERE d.[ApprovalStatusCode] <> 'PENDING'
          AND EXISTS (
              SELECT d.[ApprovalStatusCode], d.[ApprovedBy], d.[ApprovedAtUtc], d.[ApprovalNote]
              EXCEPT
              SELECT i.[ApprovalStatusCode], i.[ApprovedBy], i.[ApprovedAtUtc], i.[ApprovalNote]
          )
    )
        THROW 52122, N'An approval decision is final; generate a new run instead.', 1;
END;
