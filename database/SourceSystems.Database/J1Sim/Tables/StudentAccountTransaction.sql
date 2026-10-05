-- Amount sign convention: charges and refunds increase the balance owed (positive);
-- payments and aid credits reduce it (negative). Adjustments may be either sign.
CREATE TABLE [J1Sim].[StudentAccountTransaction] (
    [TransactionId]   BIGINT          NOT NULL,
    [IdNumber]        INT             NOT NULL,
    [TermCode]        VARCHAR (10)    NOT NULL,
    [TransactionType] VARCHAR (12)    NOT NULL,
    [DetailCode]      VARCHAR (10)    NOT NULL,
    [Amount]          DECIMAL (12, 2) NOT NULL,
    [PostedDate]      DATE            NOT NULL,
    [DueDate]         DATE            NULL,
    [CreatedAtUtc]    DATETIME2 (3)   CONSTRAINT [DF_J1Sim_StudentAccountTransaction_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3)   CONSTRAINT [DF_J1Sim_StudentAccountTransaction_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_StudentAccountTransaction] PRIMARY KEY CLUSTERED ([TransactionId] ASC),
    CONSTRAINT [FK_J1Sim_StudentAccountTransaction_Student] FOREIGN KEY ([IdNumber]) REFERENCES [J1Sim].[Student] ([IdNumber]),
    CONSTRAINT [FK_J1Sim_StudentAccountTransaction_AcademicTerm] FOREIGN KEY ([TermCode]) REFERENCES [J1Sim].[AcademicTerm] ([TermCode]),
    CONSTRAINT [CK_J1Sim_StudentAccountTransaction_TransactionType]
        CHECK (([TransactionType] = 'CHARGE' OR [TransactionType] = 'PAYMENT' OR [TransactionType] = 'AID_CREDIT'
            OR [TransactionType] = 'REFUND' OR [TransactionType] = 'ADJUSTMENT')),
    CONSTRAINT [CK_J1Sim_StudentAccountTransaction_AmountSign]
        CHECK ((([TransactionType] = 'CHARGE' OR [TransactionType] = 'REFUND') AND [Amount] > 0)
            OR (([TransactionType] = 'PAYMENT' OR [TransactionType] = 'AID_CREDIT') AND [Amount] < 0)
            OR ([TransactionType] = 'ADJUSTMENT' AND [Amount] <> 0)),
    CONSTRAINT [CK_J1Sim_StudentAccountTransaction_DueDate] CHECK ([DueDate] IS NULL OR [DueDate] >= [PostedDate])
);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_StudentAccountTransaction_StudentPosted]
    ON [J1Sim].[StudentAccountTransaction] ([IdNumber] ASC, [PostedDate] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_StudentAccountTransaction_TermCode]
    ON [J1Sim].[StudentAccountTransaction] ([TermCode] ASC);
