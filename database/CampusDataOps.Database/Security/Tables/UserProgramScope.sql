-- Programs each program coordinator may see in the census roster (row-level security,
-- docs/architecture/security-model.md). Changed only through security.usp_SetProgramScope.
CREATE TABLE [security].[UserProgramScope] (
    [UserName]     NVARCHAR (128) NOT NULL,
    [ProgramCode]  VARCHAR (20)   NOT NULL,
    [GrantedBy]    NVARCHAR (128) CONSTRAINT [DF_security_UserProgramScope_GrantedBy] DEFAULT (USER_NAME()) NOT NULL,
    [GrantedAtUtc] DATETIME2 (3)  CONSTRAINT [DF_security_UserProgramScope_GrantedAtUtc] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_security_UserProgramScope] PRIMARY KEY CLUSTERED ([UserName] ASC, [ProgramCode] ASC),
    CONSTRAINT [FK_security_UserProgramScope_AcademicProgram]
        FOREIGN KEY ([ProgramCode]) REFERENCES [reference].[AcademicProgram] ([ProgramCode])
);
