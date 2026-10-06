-- Every J1-Sim person a rule found for an evaluation. Evidence is stored as flags, never as
-- copies of names, birth dates or contact values.
CREATE TABLE [integration].[MatchCandidate] (
    [MatchEvaluationId]   BIGINT        NOT NULL,
    [RuleCode]            VARCHAR (20)  NOT NULL,
    [CandidateIdNumber]   INT           NOT NULL,
    [IsStagedPerson]      BIT           NOT NULL,
    [MatchedOnSisId]      BIT           NOT NULL,
    [MatchedOnEmail]      BIT           NOT NULL,
    [MatchedOnBirthDate]  BIT           NOT NULL,
    [MatchedOnName]       BIT           NOT NULL,
    [MatchedOnPostalCode] BIT           NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3) CONSTRAINT [DF_integration_MatchCandidate_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_integration_MatchCandidate] PRIMARY KEY CLUSTERED ([MatchEvaluationId] ASC, [RuleCode] ASC, [CandidateIdNumber] ASC),
    CONSTRAINT [FK_integration_MatchCandidate_Evaluation]
        FOREIGN KEY ([MatchEvaluationId]) REFERENCES [integration].[MatchEvaluation] ([MatchEvaluationId]),
    CONSTRAINT [FK_integration_MatchCandidate_Rule] FOREIGN KEY ([RuleCode]) REFERENCES [reference].[MatchRule] ([RuleCode])
);
