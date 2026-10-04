CREATE TABLE [J1Sim].[FinancialAidAward] (
    [AwardId]         BIGINT          NOT NULL,
    [IdNumber]        INT             NOT NULL,
    [AidYear]         CHAR (9)        NOT NULL,
    [TermCode]        VARCHAR (10)    NOT NULL,
    [FundCode]        VARCHAR (15)    NOT NULL,
    [AwardStatus]     VARCHAR (10)    NOT NULL,
    [OfferedAmount]   DECIMAL (12, 2) NOT NULL,
    [AcceptedAmount]  DECIMAL (12, 2) NOT NULL,
    [DisbursedAmount] DECIMAL (12, 2) NOT NULL,
    [CreatedAtUtc]    DATETIME2 (3)   CONSTRAINT [DF_J1Sim_FinancialAidAward_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]    DATETIME2 (3)   CONSTRAINT [DF_J1Sim_FinancialAidAward_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_J1Sim_FinancialAidAward] PRIMARY KEY CLUSTERED ([AwardId] ASC),
    CONSTRAINT [FK_J1Sim_FinancialAidAward_Student] FOREIGN KEY ([IdNumber]) REFERENCES [J1Sim].[Student] ([IdNumber]),
    CONSTRAINT [FK_J1Sim_FinancialAidAward_AcademicTerm] FOREIGN KEY ([TermCode]) REFERENCES [J1Sim].[AcademicTerm] ([TermCode]),
    CONSTRAINT [UQ_J1Sim_FinancialAidAward_StudentTermFund] UNIQUE ([IdNumber], [TermCode], [FundCode]),
    CONSTRAINT [CK_J1Sim_FinancialAidAward_FundCode]
        CHECK (([FundCode] = 'PELL' OR [FundCode] = 'SEOG' OR [FundCode] = 'MASSGRANT' OR [FundCode] = 'DIRECT_SUB'
            OR [FundCode] = 'DIRECT_UNSUB' OR [FundCode] = 'INST_SCHOL')),
    CONSTRAINT [CK_J1Sim_FinancialAidAward_AwardStatus]
        CHECK (([AwardStatus] = 'OFFERED' OR [AwardStatus] = 'ACCEPTED' OR [AwardStatus] = 'DECLINED' OR [AwardStatus] = 'CANCELLED')),
    CONSTRAINT [CK_J1Sim_FinancialAidAward_AmountOrder]
        CHECK ([OfferedAmount] > 0 AND [AcceptedAmount] >= 0 AND [DisbursedAmount] >= 0
            AND [AcceptedAmount] <= [OfferedAmount] AND [DisbursedAmount] <= [AcceptedAmount]),
    CONSTRAINT [CK_J1Sim_FinancialAidAward_AidYear] CHECK ([AidYear] LIKE '[12][0-9][0-9][0-9]-[12][0-9][0-9][0-9]')
);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_FinancialAidAward_TermCode]
    ON [J1Sim].[FinancialAidAward] ([TermCode] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_J1Sim_FinancialAidAward_UpdatedAtUtc]
    ON [J1Sim].[FinancialAidAward] ([UpdatedAtUtc] ASC);
