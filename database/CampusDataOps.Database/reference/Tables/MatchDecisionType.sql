-- Outcome of one match evaluation. AllowsProcessing marks decisions that may be queued for
-- J1-Sim; blocked decisions name the exception reason they raise.
CREATE TABLE [reference].[MatchDecisionType] (
    [DecisionTypeCode]    VARCHAR (20)   NOT NULL,
    [Description]         NVARCHAR (400) NOT NULL,
    [AllowsProcessing]    BIT            NOT NULL,
    [IsManual]            BIT            NOT NULL,
    [ExceptionReasonCode] VARCHAR (40)   NULL,
    [CreatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_MatchDecisionType_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)  CONSTRAINT [DF_reference_MatchDecisionType_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_MatchDecisionType] PRIMARY KEY CLUSTERED ([DecisionTypeCode] ASC),
    CONSTRAINT [FK_reference_MatchDecisionType_ExceptionReason]
        FOREIGN KEY ([ExceptionReasonCode]) REFERENCES [reference].[ExceptionReason] ([ExceptionReasonCode]),
    CONSTRAINT [CK_reference_MatchDecisionType_BlockedHasReason]
        CHECK (([AllowsProcessing] = 1 AND [ExceptionReasonCode] IS NULL)
            OR ([AllowsProcessing] = 0 AND [ExceptionReasonCode] IS NOT NULL))
);
