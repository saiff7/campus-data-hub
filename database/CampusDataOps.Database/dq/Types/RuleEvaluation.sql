-- One evaluated record for one rule. IsFailure = 1 rows become dq.RuleResult rows; all rows
-- count towards dq.RuleExecution.RecordsEvaluated.
CREATE TYPE [dq].[RuleEvaluation] AS TABLE (
    [RuleCode]   VARCHAR (40)  NOT NULL,
    [RecordKey]  VARCHAR (100) NOT NULL,
    [IsFailure]  BIT           NOT NULL,
    [DetailCode] VARCHAR (200) NULL,
    PRIMARY KEY ([RuleCode], [RecordKey])
);
