-- Ordered steps of the NIGHTLY_INTEGRATION pipeline. A step runs only after every earlier
-- step in the same run has SUCCEEDED or been SKIPPED by a recovery run.
CREATE TABLE [reference].[PipelineStep] (
    [StepCode]     VARCHAR (20)   NOT NULL,
    [StepOrder]    SMALLINT       NOT NULL,
    [Description]  NVARCHAR (400) NOT NULL,
    [CreatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_reference_PipelineStep_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_reference_PipelineStep_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_PipelineStep] PRIMARY KEY CLUSTERED ([StepCode] ASC),
    CONSTRAINT [UQ_reference_PipelineStep_StepOrder] UNIQUE ([StepOrder]),
    CONSTRAINT [CK_reference_PipelineStep_StepOrder] CHECK ([StepOrder] > 0)
);
