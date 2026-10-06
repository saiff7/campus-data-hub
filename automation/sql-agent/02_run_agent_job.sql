/*
Starts an Agent job and waits for it to finish, failing if the job fails or does not finish
within 10 minutes. Used by `make agent-run` (JOB= selects the job; the nightly integration job
by default) and CI; the job history and audit tables hold the details.

    sqlcmd ... -v JobName="CampusDataOps - Nightly Integration" -i 02_run_agent_job.sql
*/
SET NOCOUNT ON;

USE [msdb];

DECLARE @JobName SYSNAME = N'$(JobName)';
DECLARE @StartedAt DATETIME = DATEADD(SECOND, -1, GETDATE());
DECLARE @Deadline DATETIME = DATEADD(MINUTE, 10, GETDATE());
DECLARE @HistoryId INT;
DECLARE @RunStatus INT;
DECLARE @Message NVARCHAR (4000);

EXEC [dbo].[sp_start_job] @job_name = @JobName;

WHILE GETDATE() < @Deadline
BEGIN
    WAITFOR DELAY '00:00:02';

    SELECT TOP (1) @HistoryId = a.[job_history_id]
    FROM [dbo].[sysjobactivity] AS a
    INNER JOIN [dbo].[sysjobs] AS j ON a.[job_id] = j.[job_id]
    WHERE j.[name] = @JobName
      AND a.[start_execution_date] >= @StartedAt
      AND a.[stop_execution_date] IS NOT NULL
    ORDER BY a.[start_execution_date] DESC;

    IF @HistoryId IS NOT NULL
        BREAK;
END;

IF @HistoryId IS NULL
    THROW 50950, N'The Agent job did not finish within 10 minutes.', 1;

SELECT @RunStatus = h.[run_status], @Message = h.[message]
FROM [dbo].[sysjobhistory] AS h
WHERE h.[instance_id] = @HistoryId;

SELECT h.[step_id], h.[step_name], h.[run_status], h.[run_duration]
FROM [dbo].[sysjobhistory] AS h
INNER JOIN [dbo].[sysjobs] AS j ON h.[job_id] = j.[job_id]
WHERE j.[name] = @JobName
  AND h.[instance_id] <= @HistoryId
  AND h.[instance_id] > ISNULL((
      SELECT MAX(earlier_run.[instance_id])
      FROM [dbo].[sysjobhistory] AS earlier_run
      WHERE earlier_run.[job_id] = h.[job_id] AND earlier_run.[step_id] = 0 AND earlier_run.[instance_id] < @HistoryId
  ), 0)
ORDER BY h.[instance_id];

-- run_status 1 = succeeded.
IF @RunStatus <> 1
    THROW 50951, @Message, 1;

PRINT CONCAT(@JobName, N' succeeded.');
