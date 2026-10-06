-- Control totals of an extract run (docs/specifications/extract-controls.md). Builders write
-- ExpectedValue (computed independently of the extract rows, or NULL for an information-only
-- control) and ActualValue (computed from the rows); compliance.usp_ValidateExtractControlTotals
-- sets the prior-period comparison and the outcome. Frozen once the run completes.
CREATE TABLE [compliance].[ExtractControlTotal] (
    [ExtractRunId]       BIGINT          NOT NULL,
    [ControlCode]        VARCHAR (40)    NOT NULL,
    [ControlKind]        VARCHAR (15)    NOT NULL,
    [ComparisonOperator] VARCHAR (2)     CONSTRAINT [DF_compliance_ExtractControlTotal_ComparisonOperator] DEFAULT ('=') NOT NULL,
    [ExpectedValue]      DECIMAL (19, 2) NULL,
    [ActualValue]        DECIMAL (19, 2) NOT NULL,
    [PriorExtractRunId]  BIGINT          NULL,
    [PriorValue]         DECIMAL (19, 2) NULL,
    [ChangePct]          DECIMAL (9, 2)  NULL,
    [ThresholdPct]       DECIMAL (9, 2)  NULL,
    [OutcomeCode]        VARCHAR (4)     NULL,
    [Note]               NVARCHAR (400)  NULL,
    CONSTRAINT [PK_compliance_ExtractControlTotal] PRIMARY KEY CLUSTERED ([ExtractRunId] ASC, [ControlCode] ASC),
    CONSTRAINT [FK_compliance_ExtractControlTotal_ExtractRun]
        FOREIGN KEY ([ExtractRunId]) REFERENCES [compliance].[ExtractRun] ([ExtractRunId]),
    CONSTRAINT [CK_compliance_ExtractControlTotal_Kind]
        CHECK (([ControlKind] = 'RECONCILIATION' OR [ControlKind] = 'SUBTOTAL' OR [ControlKind] = 'RULE' OR [ControlKind] = 'INFO')),
    CONSTRAINT [CK_compliance_ExtractControlTotal_Operator]
        CHECK (([ComparisonOperator] = '=' OR [ComparisonOperator] = '>=' OR [ComparisonOperator] = '<=')),
    CONSTRAINT [CK_compliance_ExtractControlTotal_Outcome]
        CHECK ([OutcomeCode] IS NULL OR [OutcomeCode] = 'PASS' OR [OutcomeCode] = 'WARN' OR [OutcomeCode] = 'FAIL')
);
GO

CREATE TRIGGER [compliance].[trg_ExtractControlTotal_Immutable]
ON [compliance].[ExtractControlTotal]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT i.[ExtractRunId] FROM inserted AS i
            UNION
            SELECT d.[ExtractRunId] FROM deleted AS d
        ) AS changed
        INNER JOIN [compliance].[ExtractRun] AS r ON changed.[ExtractRunId] = r.[ExtractRunId]
        WHERE r.[ExtractStatusCode] <> 'GENERATING'
    )
        THROW 52124, N'Control totals of a completed extract run cannot change.', 1;
END;
