CREATE TYPE [integration].[ExceptionTransitionList] AS TABLE (
    [ExceptionId]  BIGINT       NOT NULL PRIMARY KEY,
    [ToStatusCode] VARCHAR (30) NOT NULL
);
