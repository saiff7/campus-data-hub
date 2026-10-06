-- An owner's decision about a recurring data-quality failure (docs/specifications/data-quality-rules.md):
-- fix it in the source, accept it as a known exception until a review date, or mark it a false
-- positive. One current disposition per rule and record; earlier ones are kept, superseded.
-- Dispositions annotate findings; they never suppress them from the scorecard.
CREATE TABLE [dq].[IssueDisposition] (
    [IssueDispositionId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [RuleCode]           VARCHAR (40)   NOT NULL,
    [RecordKey]          VARCHAR (100)  NOT NULL,
    [DispositionCode]    VARCHAR (20)   NOT NULL,
    [Note]               NVARCHAR (400) NOT NULL,
    [ReviewBy]           DATE           NULL,
    [IsCurrent]          BIT            NOT NULL,
    [DecidedBy]          NVARCHAR (128) CONSTRAINT [DF_dq_IssueDisposition_DecidedBy] DEFAULT (USER_NAME()) NOT NULL,
    [DecidedAtUtc]       DATETIME2 (3)  CONSTRAINT [DF_dq_IssueDisposition_DecidedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [SupersededAtUtc]    DATETIME2 (3)  NULL,
    CONSTRAINT [PK_dq_IssueDisposition] PRIMARY KEY CLUSTERED ([IssueDispositionId] ASC),
    CONSTRAINT [FK_dq_IssueDisposition_Rule] FOREIGN KEY ([RuleCode]) REFERENCES [dq].[Rule] ([RuleCode]),
    CONSTRAINT [CK_dq_IssueDisposition_DispositionCode]
        CHECK (([DispositionCode] = 'FIX_IN_SOURCE' OR [DispositionCode] = 'ACCEPTED_EXCEPTION'
            OR [DispositionCode] = 'FALSE_POSITIVE')),
    CONSTRAINT [CK_dq_IssueDisposition_AcceptedNeedsReview]
        CHECK ([DispositionCode] <> 'ACCEPTED_EXCEPTION' OR [ReviewBy] IS NOT NULL),
    CONSTRAINT [CK_dq_IssueDisposition_Current]
        CHECK (([IsCurrent] = 1 AND [SupersededAtUtc] IS NULL) OR ([IsCurrent] = 0 AND [SupersededAtUtc] IS NOT NULL))
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_dq_IssueDisposition_CurrentPerRecord]
    ON [dq].[IssueDisposition] ([RuleCode] ASC, [RecordKey] ASC)
    WHERE ([IsCurrent] = 1);
