/*
Creates (or re-creates) the SQL Server Agent job CampusDataOps - Daily Operational Reports.

    make agent-install

One T-SQL step in CampusDataOps runs compliance.usp_RunScheduledExtracts @ScheduleCode = 'DAILY'
(docs/specifications/extract-controls.md): ACCOUNT_AGING (as of today), AID_PACKAGING and
LEADERSHIP_KPI (current academic year), and EXCEPTION_WORKLIST.
The procedure continues past a failed item and fails the step at the end, so a failure is visible
in job history; every run is recorded in compliance.ExtractRun.

The schedule runs daily at 06:00 in the server's time zone (UTC in the container). Rerunning this
script replaces the job definition and resets its Agent history.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [msdb];

DECLARE @JobName SYSNAME = N'CampusDataOps - Daily Operational Reports';
DECLARE @ScheduleName SYSNAME = N'CampusDataOps - Daily 06:00';
DECLARE @JobId UNIQUEIDENTIFIER;
DECLARE @Steps TABLE (
    [StepId]   INT           NOT NULL PRIMARY KEY,
    [StepName] SYSNAME       NOT NULL,
    [Command]  NVARCHAR (400) NOT NULL
);

INSERT INTO @Steps ([StepId], [StepName], [Command])
VALUES
    (1, N'RUN_SCHEDULE', N'EXEC [compliance].[usp_RunScheduledExtracts] @ScheduleCode = N''DAILY'';');

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM [dbo].[sysjobs] AS j WHERE j.[name] = @JobName)
    EXEC [dbo].[sp_delete_job] @job_name = @JobName, @delete_unused_schedule = 1;

EXEC [dbo].[sp_add_job]
    @job_name = @JobName,
    @enabled = 1,
    @description = N'Daily operational extracts: account aging, aid packaging, exception worklist and leadership KPIs.',
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
    @active_start_time = 60000;

EXEC [dbo].[sp_attach_schedule] @job_id = @JobId, @schedule_name = @ScheduleName;

EXEC [dbo].[sp_add_jobserver] @job_id = @JobId, @server_name = N'(local)';

COMMIT TRANSACTION;

PRINT CONCAT(N'Created SQL Server Agent job ', @JobName, N'.');
