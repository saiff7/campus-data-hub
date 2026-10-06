-- Write actions the outbound queue can request from the J1-Sim import interface.
-- RequiresTargetIdNumber = 1 when the action applies to an existing J1-Sim person.
CREATE TABLE [reference].[OutboundAction] (
    [ActionCode]             VARCHAR (30)   NOT NULL,
    [Description]            NVARCHAR (400) NOT NULL,
    [RequiresTargetIdNumber] BIT            NOT NULL,
    [ReconciliationOutcome]  VARCHAR (20)   NOT NULL,
    [CreatedAtUtc]           DATETIME2 (3)  CONSTRAINT [DF_reference_OutboundAction_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]           DATETIME2 (3)  CONSTRAINT [DF_reference_OutboundAction_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_OutboundAction] PRIMARY KEY CLUSTERED ([ActionCode] ASC),
    CONSTRAINT [FK_reference_OutboundAction_ReconciliationOutcome]
        FOREIGN KEY ([ReconciliationOutcome]) REFERENCES [reference].[ReconciliationOutcome] ([OutcomeCode])
);
