/*
Creates (or re-creates) the SQL Server Agent job CampusDataOps - Nightly Integration.

    make agent-install

Steps, each a T-SQL step in CampusDataOps; every step quits the job on failure:
     1 START         integration.usp_StartPipelineRun
     2 LOAD          integration.usp_RunPipelineStep @StepCode = 'LOAD'
     3 STAGE         ... 'STAGE'
     4 DATA_QUALITY  ... 'DATA_QUALITY'
     5 MATCH         ... 'MATCH'
     6 QUEUE         ... 'QUEUE'
     7 PROCESS       ... 'PROCESS'
     8 RECONCILE     ... 'RECONCILE'
     9 NOTIFY        ... 'NOTIFY' (closes the run SUCCEEDED only when it reconciles)

Recovery after a failed run (docs/runbooks/failed-job-recovery.md): open a recovery run with
integration.usp_OpenRecoveryRun, then start the job at the chosen step:
    EXEC msdb.dbo.sp_start_job @job_name = N'CampusDataOps - Nightly Integration', @step_name = N'PROCESS';
Agent steps run in separate sessions; usp_RunPipelineStep finds the single RUNNING run.

The schedule runs daily at 02:00 in the server's time zone (UTC in the container). Rerunning
this script replaces the job definition; job history is kept by Agent per job id, so it is
reset when the job is re-created.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [msdb];

DECLARE @JobName SYSNAME = N'CampusDataOps - Nightly Integration';
DECLARE @ScheduleName SYSNAME = N'CampusDataOps - Nightly 02:00';
DECLARE @JobId UNIQUEIDENTIFIER;
DECLARE @Steps TABLE (
    [StepId]   INT           NOT NULL PRIMARY KEY,
    [StepName] SYSNAME       NOT NULL,
    [Command]  NVARCHAR (400) NOT NULL
);

INSERT INTO @Steps ([StepId], [StepName], [Command])
VALUES
    (1, N'START', N'EXEC [integration].[usp_StartPipelineRun];'),
    (2, N'LOAD', N'EXEC [integration].[usp_RunPipelineStep] @StepCode = N''LOAD'';'),
    (3, N'STAGE', N'EXEC [integration].[usp_RunPipelineStep] @StepCode = N''STAGE'';'),
    (4, N'DATA_QUALITY', N'EXEC [integration].[usp_RunPipelineStep] @StepCode = N''DATA_QUALITY'';'),
    (5, N'MATCH', N'EXEC [integration].[usp_RunPipelineStep] @StepCode = N''MATCH'';'),
    (6, N'QUEUE', N'EXEC [integration].[usp_RunPipelineStep] @StepCode = N''QUEUE'';'),
    (7, N'PROCESS', N'EXEC [integration].[usp_RunPipelineStep] @StepCode = N''PROCESS'';'),
    (8, N'RECONCILE', N'EXEC [integration].[usp_RunPipelineStep] @StepCode = N''RECONCILE'';'),
    (9, N'NOTIFY', N'EXEC [integration].[usp_RunPipelineStep] @StepCode = N''NOTIFY'';');

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM [dbo].[sysjobs] AS j WHERE j.[name] = @JobName)
    EXEC [dbo].[sp_delete_job] @job_name = @JobName, @delete_unused_schedule = 1;

EXEC [dbo].[sp_add_job]
    @job_name = @JobName,
    @enabled = 1,
    @description = N'Slate-Sim to J1-Sim applicant integration: load, stage, data quality, match, queue, process, reconcile, notify.',
    @owner_login_name = N'sa',
    @job_id = @JobId OUTPUT;

DECLARE @StepId INT = 0;
DECLARE @StepName SYSNAME;
DECLARE @Command NVARCHAR (400);
DECLARE @OnSuccess TINYINT;

-- Agent's API adds steps one call at a time.
WHILE 1 = 1
BEGIN
    SELECT TOP (1) @StepId = s.[StepId], @StepName = s.[StepName], @Command = s.[Command]
    FROM @Steps AS s
    WHERE s.[StepId] > @StepId
    ORDER BY s.[StepId];

    IF @@ROWCOUNT = 0
        BREAK;

    -- 3 = go to the next step, 1 = quit reporting success (last step); failure always quits (2).
    SET @OnSuccess = CASE WHEN @StepId = (SELECT MAX(s.[StepId]) FROM @Steps AS s) THEN 1 ELSE 3 END;

    EXEC [dbo].[sp_add_jobstep]
        @job_id = @JobId,
        @step_id = @StepId,
        @step_name = @StepName,
        @subsystem = N'TSQL',
        @database_name = N'CampusDataOps',
        @command = @Command,
        @on_success_action = @OnSuccess,
        @on_fail_action = 2,
        @retry_attempts = 0;
END;

EXEC [dbo].[sp_add_schedule]
    @schedule_name = @ScheduleName,
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 20000;

EXEC [dbo].[sp_attach_schedule] @job_id = @JobId, @schedule_name = @ScheduleName;

EXEC [dbo].[sp_add_jobserver] @job_id = @JobId, @server_name = N'(local)';

COMMIT TRANSACTION;

PRINT CONCAT(N'Created SQL Server Agent job ', @JobName, N'.');
