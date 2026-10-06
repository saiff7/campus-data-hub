-- Integration exceptions (codes and ages only). Grain: exception.
CREATE VIEW [bi].[FactIntegrationException]
AS
SELECT
    e.[ExceptionId],
    e.[ExceptionReasonCode],
    e.[ExceptionStatusCode],
    e.[Severity],
    e.[OccurrenceCount],
    s.[IsActiveState],
    CAST(e.[CreatedAtUtc] AS DATE) AS [CreatedDate],
    DATEDIFF(DAY, e.[CreatedAtUtc], SYSUTCDATETIME()) AS [AgeDays]
FROM [integration].[IntegrationException] AS e
INNER JOIN [reference].[ExceptionStatus] AS s ON e.[ExceptionStatusCode] = s.[ExceptionStatusCode];
