-- The exact CSV lines of an extract run; line 1 is the header. Written only while the run is
-- GENERATING; afterwards the trigger rejects every change.
CREATE TABLE [compliance].[ExtractRow] (
    [ExtractRunId] BIGINT          NOT NULL,
    [LineNumber]   INT             NOT NULL,
    [LineText]     NVARCHAR (4000) NOT NULL,
    CONSTRAINT [PK_compliance_ExtractRow] PRIMARY KEY CLUSTERED ([ExtractRunId] ASC, [LineNumber] ASC),
    CONSTRAINT [FK_compliance_ExtractRow_ExtractRun] FOREIGN KEY ([ExtractRunId]) REFERENCES [compliance].[ExtractRun] ([ExtractRunId]),
    CONSTRAINT [CK_compliance_ExtractRow_LineNumber] CHECK ([LineNumber] >= 1)
);
GO

CREATE TRIGGER [compliance].[trg_ExtractRow_Immutable]
ON [compliance].[ExtractRow]
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
        THROW 52123, N'Lines of a completed extract run cannot change.', 1;
END;
