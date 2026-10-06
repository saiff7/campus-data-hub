/*
Reference seed for the Part 2 integration workflow. Same contract as reference_seed.sql:
idempotent, inserts missing rows, updates rows whose governed values differ, never deletes.
Runs after reference_seed.sql because MatchDecisionType references ExceptionReason.
The values implement docs/specifications/matching-rules.md and integration-controls.md.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Change detection uses WHERE EXISTS (SELECT s.cols EXCEPT SELECT t.cols): a NULL-safe
-- comparison through correlated outer references, which SQLFluff RF01 cannot resolve.
-- noqa: disable=RF01

BEGIN TRANSACTION;

DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();

------------------------------------------------------------------------------------------
DECLARE @MatchRule TABLE (
    [RuleCode]            VARCHAR (20)   NOT NULL PRIMARY KEY,
    [Priority]            TINYINT        NOT NULL,
    [Description]         NVARCHAR (400) NOT NULL,
    [ConfidenceCategory]  VARCHAR (10)   NOT NULL,
    [IsAutoMatchEligible] BIT            NOT NULL
);

INSERT INTO @MatchRule ([RuleCode], [Priority], [Description], [ConfidenceCategory], [IsAutoMatchEligible])
VALUES
    ('CROSSWALK', 1, N'An existing source crosswalk links the Slate-Sim person to a J1-Sim ID number.', 'EXACT', 1),
    ('SIS_ID', 2, N'The applicant''s SIS ID claim equals a J1-Sim ID number.', 'EXACT', 1),
    ('EMAIL_DOB', 3, N'Normalized email and birth date are equal.', 'HIGH', 1),
    ('NAME_DOB_POSTAL', 4, N'Normalized first and last name, birth date and five-digit postal code are equal. Review only.', 'REVIEW', 0);

UPDATE t
SET t.[Priority] = s.[Priority],
    t.[Description] = s.[Description],
    t.[ConfidenceCategory] = s.[ConfidenceCategory],
    t.[IsAutoMatchEligible] = s.[IsAutoMatchEligible],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[MatchRule] AS t
INNER JOIN @MatchRule AS s ON t.[RuleCode] = s.[RuleCode]
WHERE EXISTS (
    SELECT s.[Priority], s.[Description], s.[ConfidenceCategory], s.[IsAutoMatchEligible]
    EXCEPT
    SELECT t.[Priority], t.[Description], t.[ConfidenceCategory], t.[IsAutoMatchEligible]
);

INSERT INTO [reference].[MatchRule] ([RuleCode], [Priority], [Description], [ConfidenceCategory], [IsAutoMatchEligible])
SELECT s.[RuleCode], s.[Priority], s.[Description], s.[ConfidenceCategory], s.[IsAutoMatchEligible]
FROM @MatchRule AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[MatchRule] AS t WHERE t.[RuleCode] = s.[RuleCode]);

------------------------------------------------------------------------------------------
DECLARE @MatchDecisionType TABLE (
    [DecisionTypeCode]    VARCHAR (20)   NOT NULL PRIMARY KEY,
    [Description]         NVARCHAR (400) NOT NULL,
    [AllowsProcessing]    BIT            NOT NULL,
    [IsManual]            BIT            NOT NULL,
    [ExceptionReasonCode] VARCHAR (40)   NULL
);

INSERT INTO @MatchDecisionType ([DecisionTypeCode], [Description], [AllowsProcessing], [IsManual], [ExceptionReasonCode])
VALUES
    ('AUTO_MATCH', N'Exactly one J1-Sim person satisfied the highest automatic rule with candidates.', 1, 0, NULL),
    ('NEW_PERSON', N'No rule found a candidate; the applicant becomes a new J1-Sim person.', 1, 0, NULL),
    ('AMBIGUOUS', N'Two or more J1-Sim people satisfied the deciding automatic rule.', 0, 0, 'AMBIGUOUS_MATCH'),
    ('REVIEW_REQUIRED', N'Only the review-only rule found candidates.', 0, 0, 'POSSIBLE_MATCH_REVIEW'),
    ('IDENTITY_CONFLICT', N'Identifiers or rules disagree about who the applicant is.', 0, 0, 'IDENTITY_CONFLICT'),
    ('MANUAL_MATCH', N'An authorized analyst linked the applicant to a J1-Sim person.', 1, 1, NULL),
    ('MANUAL_NEW_PERSON', N'An authorized analyst confirmed the applicant is a new person.', 1, 1, NULL);

UPDATE t
SET t.[Description] = s.[Description],
    t.[AllowsProcessing] = s.[AllowsProcessing],
    t.[IsManual] = s.[IsManual],
    t.[ExceptionReasonCode] = s.[ExceptionReasonCode],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[MatchDecisionType] AS t
INNER JOIN @MatchDecisionType AS s ON t.[DecisionTypeCode] = s.[DecisionTypeCode]
WHERE EXISTS (
    SELECT s.[Description], s.[AllowsProcessing], s.[IsManual], s.[ExceptionReasonCode]
    EXCEPT
    SELECT t.[Description], t.[AllowsProcessing], t.[IsManual], t.[ExceptionReasonCode]
);

INSERT INTO [reference].[MatchDecisionType] ([DecisionTypeCode], [Description], [AllowsProcessing], [IsManual], [ExceptionReasonCode])
SELECT s.[DecisionTypeCode], s.[Description], s.[AllowsProcessing], s.[IsManual], s.[ExceptionReasonCode]
FROM @MatchDecisionType AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[MatchDecisionType] AS t WHERE t.[DecisionTypeCode] = s.[DecisionTypeCode]);

------------------------------------------------------------------------------------------
DECLARE @ExceptionStatus TABLE (
    [ExceptionStatusCode] VARCHAR (30)   NOT NULL PRIMARY KEY,
    [Description]         NVARCHAR (400) NOT NULL,
    [IsActiveState]       BIT            NOT NULL,
    [SortOrder]           TINYINT        NOT NULL
);

INSERT INTO @ExceptionStatus ([ExceptionStatusCode], [Description], [IsActiveState], [SortOrder])
VALUES
    ('OPEN', N'Raised, or reopened because the condition came back.', 1, 1),
    ('ASSIGNED', N'An analyst owns the exception.', 1, 2),
    ('AWAITING_SOURCE_CORRECTION', N'The fix must be made in the source system.', 1, 3),
    ('RESOLVED', N'A resolution was recorded, or the condition disappeared.', 1, 4),
    ('RETRY_READY', N'Approved for the next processing attempt.', 1, 5),
    ('REPROCESSED', N'The application was written to J1-Sim after the retry.', 0, 6),
    ('CLOSED', N'Finished; no further action.', 0, 7);

UPDATE t
SET t.[Description] = s.[Description],
    t.[IsActiveState] = s.[IsActiveState],
    t.[SortOrder] = s.[SortOrder],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ExceptionStatus] AS t
INNER JOIN @ExceptionStatus AS s ON t.[ExceptionStatusCode] = s.[ExceptionStatusCode]
WHERE EXISTS (
    SELECT s.[Description], s.[IsActiveState], s.[SortOrder]
    EXCEPT
    SELECT t.[Description], t.[IsActiveState], t.[SortOrder]
);

INSERT INTO [reference].[ExceptionStatus] ([ExceptionStatusCode], [Description], [IsActiveState], [SortOrder])
SELECT s.[ExceptionStatusCode], s.[Description], s.[IsActiveState], s.[SortOrder]
FROM @ExceptionStatus AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[ExceptionStatus] AS t WHERE t.[ExceptionStatusCode] = s.[ExceptionStatusCode]);

------------------------------------------------------------------------------------------
DECLARE @ExceptionStatusTransition TABLE (
    [FromStatusCode] VARCHAR (30)   NOT NULL,
    [ToStatusCode]   VARCHAR (30)   NOT NULL,
    [Description]    NVARCHAR (400) NOT NULL,
    PRIMARY KEY ([FromStatusCode], [ToStatusCode])
);

INSERT INTO @ExceptionStatusTransition ([FromStatusCode], [ToStatusCode], [Description])
VALUES
    ('OPEN', 'ASSIGNED', N'An analyst takes ownership.'),
    ('OPEN', 'AWAITING_SOURCE_CORRECTION', N'The fix must be made in the source system.'),
    ('OPEN', 'RESOLVED', N'Resolved without assignment, or the condition disappeared.'),
    ('OPEN', 'CLOSED', N'Closed without processing, for example the application is no longer eligible.'),
    ('ASSIGNED', 'OPEN', N'The analyst releases ownership.'),
    ('ASSIGNED', 'AWAITING_SOURCE_CORRECTION', N'The analyst requested a source correction.'),
    ('ASSIGNED', 'RESOLVED', N'The analyst recorded a resolution, or the condition disappeared.'),
    ('ASSIGNED', 'CLOSED', N'Closed without processing.'),
    ('AWAITING_SOURCE_CORRECTION', 'ASSIGNED', N'Returned to an analyst.'),
    ('AWAITING_SOURCE_CORRECTION', 'RESOLVED', N'The corrected source no longer meets the condition.'),
    ('AWAITING_SOURCE_CORRECTION', 'CLOSED', N'Closed without processing.'),
    ('RESOLVED', 'RETRY_READY', N'A blocking exception was approved for retry.'),
    ('RESOLVED', 'OPEN', N'The condition came back before the retry.'),
    ('RESOLVED', 'CLOSED', N'A non-blocking exception needs no reprocessing.'),
    ('RETRY_READY', 'REPROCESSED', N'The retry wrote the application to J1-Sim.'),
    ('RETRY_READY', 'OPEN', N'The retry reproduced the condition.'),
    ('RETRY_READY', 'CLOSED', N'The application is no longer eligible.'),
    ('REPROCESSED', 'CLOSED', N'Reconciliation confirmed the J1-Sim record.');

UPDATE t
SET t.[Description] = s.[Description],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ExceptionStatusTransition] AS t
INNER JOIN @ExceptionStatusTransition AS s
    ON t.[FromStatusCode] = s.[FromStatusCode]
   AND t.[ToStatusCode] = s.[ToStatusCode]
WHERE t.[Description] <> s.[Description];

INSERT INTO [reference].[ExceptionStatusTransition] ([FromStatusCode], [ToStatusCode], [Description])
SELECT s.[FromStatusCode], s.[ToStatusCode], s.[Description]
FROM @ExceptionStatusTransition AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM [reference].[ExceptionStatusTransition] AS t
    WHERE t.[FromStatusCode] = s.[FromStatusCode]
      AND t.[ToStatusCode] = s.[ToStatusCode]
);

------------------------------------------------------------------------------------------
DECLARE @ReconciliationOutcome TABLE (
    [OutcomeCode] VARCHAR (20)   NOT NULL PRIMARY KEY,
    [Description] NVARCHAR (400) NOT NULL,
    [SortOrder]   TINYINT        NOT NULL
);

INSERT INTO @ReconciliationOutcome ([OutcomeCode], [Description], [SortOrder])
VALUES
    ('CREATED', N'Written to J1-Sim as a new person and student in this run.', 1),
    ('MATCHED', N'Linked to an existing J1-Sim person and written as a new or readmitted student in this run.', 2),
    ('UNCHANGED', N'Written and reconciled in an earlier run; nothing new to do.', 3),
    ('REJECTED', N'Blocked by an active blocking exception.', 4),
    ('PENDING', N'In a controlled waiting state: queued, retryable or awaiting retry.', 5);

UPDATE t
SET t.[Description] = s.[Description],
    t.[SortOrder] = s.[SortOrder],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[ReconciliationOutcome] AS t
INNER JOIN @ReconciliationOutcome AS s ON t.[OutcomeCode] = s.[OutcomeCode]
WHERE EXISTS (
    SELECT s.[Description], s.[SortOrder]
    EXCEPT
    SELECT t.[Description], t.[SortOrder]
);

INSERT INTO [reference].[ReconciliationOutcome] ([OutcomeCode], [Description], [SortOrder])
SELECT s.[OutcomeCode], s.[Description], s.[SortOrder]
FROM @ReconciliationOutcome AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[ReconciliationOutcome] AS t WHERE t.[OutcomeCode] = s.[OutcomeCode]);

------------------------------------------------------------------------------------------
DECLARE @OutboundAction TABLE (
    [ActionCode]             VARCHAR (30)   NOT NULL PRIMARY KEY,
    [Description]            NVARCHAR (400) NOT NULL,
    [RequiresTargetIdNumber] BIT            NOT NULL,
    [ReconciliationOutcome]  VARCHAR (20)   NOT NULL
);

INSERT INTO @OutboundAction ([ActionCode], [Description], [RequiresTargetIdNumber], [ReconciliationOutcome])
VALUES
    ('CREATE_PERSON_STUDENT', N'Create a new J1-Sim person and an active student record.', 0, 'CREATED'),
    ('CREATE_STUDENT', N'Add an active student record to an existing J1-Sim person.', 1, 'MATCHED'),
    ('READMIT_STUDENT', N'Reactivate an existing inactive, withdrawn or graduated student with the new program and term.', 1, 'MATCHED');

UPDATE t
SET t.[Description] = s.[Description],
    t.[RequiresTargetIdNumber] = s.[RequiresTargetIdNumber],
    t.[ReconciliationOutcome] = s.[ReconciliationOutcome],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[OutboundAction] AS t
INNER JOIN @OutboundAction AS s ON t.[ActionCode] = s.[ActionCode]
WHERE EXISTS (
    SELECT s.[Description], s.[RequiresTargetIdNumber], s.[ReconciliationOutcome]
    EXCEPT
    SELECT t.[Description], t.[RequiresTargetIdNumber], t.[ReconciliationOutcome]
);

INSERT INTO [reference].[OutboundAction] ([ActionCode], [Description], [RequiresTargetIdNumber], [ReconciliationOutcome])
SELECT s.[ActionCode], s.[Description], s.[RequiresTargetIdNumber], s.[ReconciliationOutcome]
FROM @OutboundAction AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[OutboundAction] AS t WHERE t.[ActionCode] = s.[ActionCode]);

------------------------------------------------------------------------------------------
DECLARE @OutboundQueueStatus TABLE (
    [QueueStatusCode] VARCHAR (20)   NOT NULL PRIMARY KEY,
    [Description]     NVARCHAR (400) NOT NULL,
    [IsSendable]      BIT            NOT NULL,
    [IsTerminal]      BIT            NOT NULL
);

INSERT INTO @OutboundQueueStatus ([QueueStatusCode], [Description], [IsSendable], [IsTerminal])
VALUES
    ('PENDING', N'Waiting for its first or next attempt.', 1, 0),
    ('FAILED_RETRYABLE', N'The last attempt failed; it will be retried until the attempt limit.', 1, 0),
    ('FAILED_PERMANENT', N'The attempt limit was reached; an OUTBOUND_WRITE_FAILURE exception holds it.', 0, 0),
    ('SUCCEEDED', N'J1-Sim accepted the write.', 0, 1),
    ('CANCELLED', N'Superseded by a different decision or no longer eligible before it was sent.', 0, 0);

UPDATE t
SET t.[Description] = s.[Description],
    t.[IsSendable] = s.[IsSendable],
    t.[IsTerminal] = s.[IsTerminal],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[OutboundQueueStatus] AS t
INNER JOIN @OutboundQueueStatus AS s ON t.[QueueStatusCode] = s.[QueueStatusCode]
WHERE EXISTS (
    SELECT s.[Description], s.[IsSendable], s.[IsTerminal]
    EXCEPT
    SELECT t.[Description], t.[IsSendable], t.[IsTerminal]
);

INSERT INTO [reference].[OutboundQueueStatus] ([QueueStatusCode], [Description], [IsSendable], [IsTerminal])
SELECT s.[QueueStatusCode], s.[Description], s.[IsSendable], s.[IsTerminal]
FROM @OutboundQueueStatus AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[OutboundQueueStatus] AS t WHERE t.[QueueStatusCode] = s.[QueueStatusCode]);

------------------------------------------------------------------------------------------
DECLARE @PipelineStep TABLE (
    [StepCode]    VARCHAR (20)   NOT NULL PRIMARY KEY,
    [StepOrder]   SMALLINT       NOT NULL,
    [Description] NVARCHAR (400) NOT NULL
);

INSERT INTO @PipelineStep ([StepCode], [StepOrder], [Description])
VALUES
    ('LOAD', 1, N'Land changed rows from Slate-Sim, J1-Sim and Directory-Sim.'),
    ('STAGE', 2, N'Standardize landed rows into staging, keeping raw values.'),
    ('DATA_QUALITY', 3, N'Run every active data-quality rule.'),
    ('MATCH', 4, N'Raise validation exceptions and decide applicant identity.'),
    ('QUEUE', 5, N'Apply approved retries and queue ready applications for J1-Sim.'),
    ('PROCESS', 6, N'Write queued applications to J1-Sim, one transaction per row.'),
    ('RECONCILE', 7, N'Reconcile eligible applications to outcomes and confirmed J1-Sim records.'),
    ('NOTIFY', 8, N'Publish the run summary and close the run.');

UPDATE t
SET t.[StepOrder] = s.[StepOrder],
    t.[Description] = s.[Description],
    t.[UpdatedAtUtc] = @NowUtc
FROM [reference].[PipelineStep] AS t
INNER JOIN @PipelineStep AS s ON t.[StepCode] = s.[StepCode]
WHERE EXISTS (
    SELECT s.[StepOrder], s.[Description]
    EXCEPT
    SELECT t.[StepOrder], t.[Description]
);

INSERT INTO [reference].[PipelineStep] ([StepCode], [StepOrder], [Description])
SELECT s.[StepCode], s.[StepOrder], s.[Description]
FROM @PipelineStep AS s
WHERE NOT EXISTS (SELECT 1 FROM [reference].[PipelineStep] AS t WHERE t.[StepCode] = s.[StepCode]);

-- noqa: enable=RF01

COMMIT TRANSACTION;
