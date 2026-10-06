-- One row for the Power BI data-as-of and refresh-status indicators: the last successful nightly
-- run, the source watermarks it reached, the latest census snapshot and validation run, and the
-- time this view was read (the refresh time in import mode).
CREATE VIEW [bi].[DataAsOf]
AS
WITH [LastRun] AS (
    SELECT TOP (1) b.[BatchId], b.[EndedAtUtc]
    FROM [audit].[BatchRun] AS b
    WHERE b.[ProcessName] = 'NIGHTLY_INTEGRATION' AND b.[BatchStatusCode] = 'SUCCEEDED'
    ORDER BY b.[BatchId] DESC
),

[Watermark] AS (
    SELECT
        MAX(CASE WHEN c.[SourceSystemCode] = 'SLATE_SIM' THEN c.[SourceWatermarkUtc] END) AS [SlateWatermarkUtc],
        MAX(CASE WHEN c.[SourceSystemCode] = 'J1_SIM' THEN c.[SourceWatermarkUtc] END) AS [J1WatermarkUtc],
        MAX(CASE WHEN c.[SourceSystemCode] = 'DIRECTORY_SIM' THEN c.[SourceWatermarkUtc] END) AS [DirectoryWatermarkUtc]
    FROM [audit].[BatchRun] AS c
    INNER JOIN [LastRun] AS l ON c.[ParentBatchId] = l.[BatchId]
    WHERE c.[SourceWatermarkUtc] IS NOT NULL
)

SELECT
    l.[BatchId] AS [LastSuccessfulRunId],
    l.[EndedAtUtc] AS [LastSuccessfulRunEndedAtUtc],
    w.[SlateWatermarkUtc],
    w.[J1WatermarkUtc],
    w.[DirectoryWatermarkUtc],
    (SELECT MAX(s.[CapturedAtUtc]) FROM [compliance].[CensusSnapshot] AS s) AS [LatestCensusCaptureUtc],
    (SELECT MAX(v.[ValidationRunId]) FROM [dq].[ValidationRun] AS v) AS [LatestValidationRunId],
    SYSUTCDATETIME() AS [ReadAtUtc]
-- The aggregate in [Watermark] always returns one row, so the view has one row even before any run.
FROM [Watermark] AS w
LEFT JOIN [LastRun] AS l ON 1 = 1;
