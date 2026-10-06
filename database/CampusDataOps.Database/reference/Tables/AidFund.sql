-- Financial aid funds and how reports classify them. IsFederalStudentLoan marks loans made to
-- the student (IPEDS SFA "federal loans to students"; PLUS loans would be 0).
CREATE TABLE [reference].[AidFund] (
    [FundCode]             VARCHAR (15)   NOT NULL,
    [FundName]             NVARCHAR (100) NOT NULL,
    [FundSource]           VARCHAR (15)   NOT NULL,
    [FundType]             VARCHAR (10)   NOT NULL,
    [IsPell]               BIT            NOT NULL,
    [IsFederalStudentLoan] BIT            NOT NULL,
    [CreatedAtUtc]         DATETIME2 (3)  CONSTRAINT [DF_reference_AidFund_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [UpdatedAtUtc]         DATETIME2 (3)  CONSTRAINT [DF_reference_AidFund_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_reference_AidFund] PRIMARY KEY CLUSTERED ([FundCode] ASC),
    CONSTRAINT [CK_reference_AidFund_FundSource]
        CHECK (([FundSource] = 'FEDERAL' OR [FundSource] = 'STATE' OR [FundSource] = 'INSTITUTIONAL')),
    CONSTRAINT [CK_reference_AidFund_FundType] CHECK (([FundType] = 'GRANT' OR [FundType] = 'LOAN')),
    CONSTRAINT [CK_reference_AidFund_Pell] CHECK ([IsPell] = 0 OR ([FundSource] = 'FEDERAL' AND [FundType] = 'GRANT')),
    CONSTRAINT [CK_reference_AidFund_FederalStudentLoan]
        CHECK ([IsFederalStudentLoan] = 0 OR ([FundSource] = 'FEDERAL' AND [FundType] = 'LOAN'))
);
