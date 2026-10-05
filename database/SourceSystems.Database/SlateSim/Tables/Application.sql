-- EntryTermCode is free text in the CRM; it is validated against J1-Sim terms only
-- during integration, which is how an invalid term can reach the integration layer.
CREATE TABLE [SlateSim].[Application] (
    [ApplicationId]  UNIQUEIDENTIFIER NOT NULL,
    [PersonId]       UNIQUEIDENTIFIER NOT NULL,
    [EntryTermCode]  VARCHAR (10)     NULL,
    [StudentType]    VARCHAR (20)     NOT NULL,
    [CurrentStatus]  VARCHAR (20)     NOT NULL,
    [SubmittedAtUtc] DATETIME2 (3)    NULL,
    [DecisionAtUtc]  DATETIME2 (3)    NULL,
    [CreatedAtUtc]   DATETIME2 (3)    CONSTRAINT [DF_SlateSim_Application_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]   DATETIME2 (3)    CONSTRAINT [DF_SlateSim_Application_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_SlateSim_Application] PRIMARY KEY CLUSTERED ([ApplicationId] ASC),
    CONSTRAINT [FK_SlateSim_Application_Person] FOREIGN KEY ([PersonId]) REFERENCES [SlateSim].[Person] ([PersonId]),
    CONSTRAINT [CK_SlateSim_Application_StudentType]
        CHECK (([StudentType] = 'FIRST_TIME' OR [StudentType] = 'TRANSFER' OR [StudentType] = 'READMIT' OR [StudentType] = 'NON_DEGREE')),
    CONSTRAINT [CK_SlateSim_Application_CurrentStatus]
        CHECK (([CurrentStatus] = 'STARTED' OR [CurrentStatus] = 'SUBMITTED' OR [CurrentStatus] = 'COMPLETE'
            OR [CurrentStatus] = 'ADMITTED' OR [CurrentStatus] = 'DENIED' OR [CurrentStatus] = 'WITHDRAWN'
            OR [CurrentStatus] = 'DEPOSITED')),
    CONSTRAINT [CK_SlateSim_Application_DecisionAfterSubmit]
        CHECK ([DecisionAtUtc] IS NULL OR ([SubmittedAtUtc] IS NOT NULL AND [DecisionAtUtc] >= [SubmittedAtUtc])),
    CONSTRAINT [CK_SlateSim_Application_UpdatedAfterCreated] CHECK ([UpdatedAtUtc] >= [CreatedAtUtc])
);
GO

CREATE NONCLUSTERED INDEX [IX_SlateSim_Application_PersonId]
    ON [SlateSim].[Application] ([PersonId] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_SlateSim_Application_UpdatedAtUtc]
    ON [SlateSim].[Application] ([UpdatedAtUtc] ASC);
