-- Receipts of the simulated SIS import interface. The idempotency key comes from the caller's
-- outbound queue; a replay with a known key returns the original ID number and writes nothing,
-- so a lost acknowledgement can never create a second person.
CREATE TABLE [J1Sim].[IntegrationReceipt] (
    [IdempotencyKey]      BINARY (32)      NOT NULL,
    [IdNumber]            INT              NOT NULL,
    [ActionCode]          VARCHAR (30)     NOT NULL,
    [SourceApplicationId] UNIQUEIDENTIFIER NOT NULL,
    [ReceivedAtUtc]       DATETIME2 (3)    NOT NULL,
    [CreatedAtUtc]        DATETIME2 (3)    CONSTRAINT [DF_J1Sim_IntegrationReceipt_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]        DATETIME2 (3)    CONSTRAINT [DF_J1Sim_IntegrationReceipt_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_IntegrationReceipt] PRIMARY KEY CLUSTERED ([IdempotencyKey] ASC),
    CONSTRAINT [FK_J1Sim_IntegrationReceipt_Person] FOREIGN KEY ([IdNumber]) REFERENCES [J1Sim].[Person] ([IdNumber]),
    CONSTRAINT [CK_J1Sim_IntegrationReceipt_ActionCode]
        CHECK (([ActionCode] = 'CREATE_PERSON_STUDENT' OR [ActionCode] = 'CREATE_STUDENT' OR [ActionCode] = 'READMIT_STUDENT'))
);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_IntegrationReceipt_IdNumber]
    ON [J1Sim].[IntegrationReceipt] ([IdNumber] ASC);
