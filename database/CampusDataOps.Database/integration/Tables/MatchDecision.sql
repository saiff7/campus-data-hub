-- Identity decisions for eligible applications (docs/specifications/matching-rules.md). Rows
-- are never updated except to mark them superseded; exactly one is current per application.
-- The CHECK constraints are the safety net for ADR-001: whatever the procedures do, an
-- automatic match must be unique and come from an automatic rule, and a blocked decision can
-- never carry a matched ID number.
CREATE TABLE [integration].[MatchDecision] (
    [MatchDecisionId]    BIGINT           IDENTITY (1, 1) NOT NULL,
    [ApplicationId]      UNIQUEIDENTIFIER NOT NULL,
    [MatchEvaluationId]  BIGINT           NULL,
    [BatchId]            BIGINT           NULL,
    [SourceHash]         BINARY (32)      NOT NULL,
    [DecisionTypeCode]   VARCHAR (20)     NOT NULL,
    [RuleCode]           VARCHAR (20)     NULL,
    [CandidateCount]     INT              NOT NULL,
    [MatchedIdNumber]    INT              NULL,
    [ConfidenceCategory] VARCHAR (10)     NOT NULL,
    [ConflictCode]       VARCHAR (40)     NULL,
    [DecidedBy]          NVARCHAR (128)   NOT NULL,
    [DecidedAtUtc]       DATETIME2 (3)    NOT NULL,
    [Note]               NVARCHAR (1000)  NULL,
    [IsCurrent]          BIT              NOT NULL,
    [SupersededAtUtc]    DATETIME2 (3)    NULL,
    [RecordedBy]         NVARCHAR (128)   CONSTRAINT [DF_integration_MatchDecision_RecordedBy] DEFAULT (ORIGINAL_LOGIN()) NOT NULL,
    CONSTRAINT [PK_integration_MatchDecision] PRIMARY KEY CLUSTERED ([MatchDecisionId] ASC),
    CONSTRAINT [FK_integration_MatchDecision_Evaluation]
        FOREIGN KEY ([MatchEvaluationId]) REFERENCES [integration].[MatchEvaluation] ([MatchEvaluationId]),
    CONSTRAINT [FK_integration_MatchDecision_Batch] FOREIGN KEY ([BatchId]) REFERENCES [audit].[BatchRun] ([BatchId]),
    CONSTRAINT [FK_integration_MatchDecision_DecisionType]
        FOREIGN KEY ([DecisionTypeCode]) REFERENCES [reference].[MatchDecisionType] ([DecisionTypeCode]),
    CONSTRAINT [FK_integration_MatchDecision_Rule] FOREIGN KEY ([RuleCode]) REFERENCES [reference].[MatchRule] ([RuleCode]),
    CONSTRAINT [CK_integration_MatchDecision_AutoMatchIsUniqueAndAutomatic]
        CHECK ([DecisionTypeCode] <> 'AUTO_MATCH'
            OR ([CandidateCount] = 1 AND [MatchedIdNumber] IS NOT NULL AND [ConflictCode] IS NULL
                AND ([RuleCode] = 'CROSSWALK' OR [RuleCode] = 'SIS_ID' OR [RuleCode] = 'EMAIL_DOB'))),
    CONSTRAINT [CK_integration_MatchDecision_BlockedHasNoMatch]
        CHECK (([DecisionTypeCode] <> 'AMBIGUOUS' AND [DecisionTypeCode] <> 'REVIEW_REQUIRED'
                AND [DecisionTypeCode] <> 'IDENTITY_CONFLICT')
            OR [MatchedIdNumber] IS NULL),
    CONSTRAINT [CK_integration_MatchDecision_Shape]
        CHECK (([DecisionTypeCode] = 'AUTO_MATCH')
            OR ([DecisionTypeCode] = 'NEW_PERSON' AND [CandidateCount] = 0 AND [MatchedIdNumber] IS NULL
                AND [RuleCode] IS NULL AND [ConflictCode] IS NULL)
            OR ([DecisionTypeCode] = 'AMBIGUOUS' AND [CandidateCount] >= 2 AND [RuleCode] IS NOT NULL AND [ConflictCode] IS NULL)
            OR ([DecisionTypeCode] = 'REVIEW_REQUIRED' AND [CandidateCount] >= 1 AND [RuleCode] = 'NAME_DOB_POSTAL'
                AND [ConflictCode] IS NULL)
            OR ([DecisionTypeCode] = 'IDENTITY_CONFLICT' AND [ConflictCode] IS NOT NULL)
            OR ([DecisionTypeCode] = 'MANUAL_MATCH' AND [MatchedIdNumber] IS NOT NULL AND [ConflictCode] IS NULL)
            OR ([DecisionTypeCode] = 'MANUAL_NEW_PERSON' AND [MatchedIdNumber] IS NULL AND [ConflictCode] IS NULL)),
    CONSTRAINT [CK_integration_MatchDecision_ConflictCode]
        CHECK ([ConflictCode] IS NULL
            OR [ConflictCode] = 'CROSSWALK_TARGET_MISSING' OR [ConflictCode] = 'SIS_ID_INVALID_FORMAT'
            OR [ConflictCode] = 'SIS_ID_NOT_FOUND' OR [ConflictCode] = 'SIS_ID_BIRTH_DATE_MISMATCH'
            OR [ConflictCode] = 'SIS_ID_CLAIMED_BY_MULTIPLE' OR [ConflictCode] = 'RULES_DISAGREE'),
    CONSTRAINT [CK_integration_MatchDecision_ConfidenceCategory]
        CHECK (([ConfidenceCategory] = 'EXACT' OR [ConfidenceCategory] = 'HIGH' OR [ConfidenceCategory] = 'REVIEW'
            OR [ConfidenceCategory] = 'NONE' OR [ConfidenceCategory] = 'MANUAL')),
    CONSTRAINT [CK_integration_MatchDecision_CandidateCount] CHECK ([CandidateCount] >= 0),
    CONSTRAINT [CK_integration_MatchDecision_Superseded]
        CHECK (([IsCurrent] = 1 AND [SupersededAtUtc] IS NULL) OR ([IsCurrent] = 0 AND [SupersededAtUtc] IS NOT NULL))
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_integration_MatchDecision_OneCurrentPerApplication]
    ON [integration].[MatchDecision] ([ApplicationId] ASC)
    INCLUDE ([DecisionTypeCode], [MatchedIdNumber], [SourceHash], [MatchEvaluationId])
    WHERE ([IsCurrent] = 1);
