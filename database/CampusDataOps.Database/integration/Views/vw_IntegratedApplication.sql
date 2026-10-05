-- Applications already written to J1-Sim. They are never matched or queued again.
CREATE VIEW [integration].[vw_IntegratedApplication]
AS
SELECT
    q.[ApplicationId],
    q.[QueueId],
    q.[ActionCode],
    q.[ResultIdNumber],
    q.[ProcessedBatchId],
    q.[ReconciledBatchId]
FROM [integration].[OutboundStudentQueue] AS q
WHERE q.[QueueStatusCode] = 'SUCCEEDED';
