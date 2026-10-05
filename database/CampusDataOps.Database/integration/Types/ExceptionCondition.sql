-- One evaluated condition: for a subject (application or batch) and a reason, whether the
-- condition is present now. Callers list every subject they evaluated for every reason in
-- their scope, so absent conditions can resolve existing exceptions.
CREATE TYPE [integration].[ExceptionCondition] AS TABLE (
    [ApplicationId]       UNIQUEIDENTIFIER NULL,
    [SubjectBatchId]      BIGINT           NULL,
    [ExceptionReasonCode] VARCHAR (40)     NOT NULL,
    [IsPresent]           BIT              NOT NULL,
    [DetailCode]          VARCHAR (200)    NULL,
    [SourceHash]          BINARY (32)      NULL
);
