/*
tSQLt tests for extract runs and controls (docs/specifications/extract-controls.md): CSV field
rules, generation, checksums, control outcomes, failure recording, approval rules and the
immutability triggers. The data-quality scorecard view is faked through a helper procedure;
SetFakeViewOn lets that procedure insert into the multi-table view and is switched off at the end.
*/
EXEC tSQLt.NewTestClass @ClassName = N'ComplianceTests';
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'dq';
GO

EXEC tSQLt.SetFakeViewOn @SchemaName = N'dq';
GO

CREATE PROCEDURE [ComplianceTests].[AddScorecard]
AS
BEGIN
    INSERT INTO [dq].[vw_DataQualityScorecard] (
        [ValidationRunId], [BatchId], [RuleCode], [EntityName], [Severity], [OwnerDepartment], [RecordsEvaluated], [RecordsFailed],
        [PassRate]
    )
    VALUES
        (5, 7, 'APP_EMAIL_FORMAT', 'APPLICATION', 'LOW', N'Admissions', 300, 3, 0.990000),
        (5, 7, 'SIS_DUPLICATE_PERSON', 'SIS_PERSON', 'HIGH', N'Registrar, Records', 2000, 0, 1.000000);
END;
GO

CREATE PROCEDURE [ComplianceTests].[FakeGenerationContext]
    @FailuresFound INT = 3
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'audit.BatchRun';
    EXEC tSQLt.FakeTable @TableName = N'audit.AccessEvent', @Identity = 1, @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRun', @Identity = 1, @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRow';
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractControlTotal', @Defaults = 1;
    EXEC tSQLt.FakeTable @TableName = N'compliance.ControlThreshold';
    EXEC tSQLt.FakeTable @TableName = N'dq.vw_DataQualityScorecard';
    EXEC tSQLt.FakeTable @TableName = N'dq.ValidationRun';

    INSERT INTO [audit].[BatchRun] ([BatchId], [ProcessName], [BatchStatusCode]) VALUES (7, 'NIGHTLY_INTEGRATION', 'SUCCEEDED');
    INSERT INTO [dq].[ValidationRun] ([ValidationRunId], [FailuresFound], [RulesEvaluated]) VALUES (5, @FailuresFound, 2);
    EXEC [ComplianceTests].[AddScorecard];
END;
GO

------------------------------------------------------------------------------------------
-- CSV fields
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ComplianceTests].[test CSV fields quote only when RFC 4180 requires it]
AS
BEGIN
    SELECT v.[Input], [compliance].[fn_CsvField](v.[Input]) AS [Field]
    INTO #Actual
    FROM (
        VALUES (N'plain'), (N'a,b'), (N'say "hi"'), (CONCAT(N'two', NCHAR(10), N'lines')), (N''), (NULL)
    ) AS v ([Input]);

    SELECT TOP (0) a.[Input], a.[Field] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([Input], [Field])
    VALUES
        (N'plain', N'plain'),
        (N'a,b', N'"a,b"'),
        (N'say "hi"', N'"say ""hi"""'),
        (CONCAT(N'two', NCHAR(10), N'lines'), CONCAT(N'"two', NCHAR(10), N'lines"')),
        (N'', N''),
        (NULL, N'');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

------------------------------------------------------------------------------------------
-- Generation
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ComplianceTests].[test generation stores the exact lines, a matching checksum and passing controls]
AS
BEGIN
    EXEC [ComplianceTests].[FakeGenerationContext];
    DECLARE @RunId BIGINT;

    EXEC [compliance].[usp_GenerateExtract] @ExtractTypeCode = 'DQ_SCORECARD', @ExtractRunId = @RunId OUTPUT, @ReturnSummary = 0;

    SELECT r.[LineNumber], r.[LineText] INTO #Actual FROM [compliance].[ExtractRow] AS r;
    SELECT TOP (0) a.[LineNumber], a.[LineText] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([LineNumber], [LineText])
    VALUES
        (1, N'ValidationRunId,BatchId,RuleCode,EntityName,Severity,OwnerDepartment,RecordsEvaluated,RecordsFailed,PassRate'),
        (2, N'5,7,APP_EMAIL_FORMAT,APPLICATION,LOW,Admissions,300,3,0.990000'),
        (3, N'5,7,SIS_DUPLICATE_PERSON,SIS_PERSON,HIGH,"Registrar, Records",2000,0,1.000000');
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    DECLARE @Content VARCHAR (MAX) = CONCAT(
        'ValidationRunId,BatchId,RuleCode,EntityName,Severity,OwnerDepartment,RecordsEvaluated,RecordsFailed,PassRate', CHAR(10),
        '5,7,APP_EMAIL_FORMAT,APPLICATION,LOW,Admissions,300,3,0.990000', CHAR(10),
        '5,7,SIS_DUPLICATE_PERSON,SIS_PERSON,HIGH,"Registrar, Records",2000,0,1.000000', CHAR(10)
    );
    DECLARE @ExpectedSha BINARY (32) = HASHBYTES('SHA2_256', @Content);

    SELECT r.[ExtractStatusCode], r.[ValidationStatusCode], r.[ApprovalStatusCode], r.[LineCount], r.[DataRowCount], r.[ContentSha256]
    INTO #Run
    FROM [compliance].[ExtractRun] AS r;
    SELECT TOP (0)
        a.[ExtractStatusCode], a.[ValidationStatusCode], a.[ApprovalStatusCode], a.[LineCount], a.[DataRowCount], a.[ContentSha256]
    INTO #ExpectedRun
    FROM #Run AS a;
    INSERT INTO #ExpectedRun (
        [ExtractStatusCode], [ValidationStatusCode], [ApprovalStatusCode], [LineCount], [DataRowCount], [ContentSha256]
    )
    VALUES ('SUCCEEDED', 'PASSED', 'PENDING', 3, 2, @ExpectedSha);
    EXEC tSQLt.AssertEqualsTable @Expected = N'#ExpectedRun', @Actual = N'#Run';

    DECLARE @Audited INT = (
        SELECT COUNT(*) FROM [audit].[AccessEvent] AS e WHERE e.[EventType] = 'EXTRACT_GENERATE' AND e.[IsAllowed] = 1
    );
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @Audited;
END;
GO

CREATE PROCEDURE [ComplianceTests].[test a control mismatch is recorded as FAILED validation, not hidden]
AS
BEGIN
    EXEC [ComplianceTests].[FakeGenerationContext] @FailuresFound = 4;

    EXEC [compliance].[usp_GenerateExtract] @ExtractTypeCode = 'DQ_SCORECARD', @ReturnSummary = 0;

    SELECT r.[ExtractStatusCode], r.[ValidationStatusCode], c.[ExpectedValue], c.[ActualValue], c.[OutcomeCode]
    INTO #Actual
    FROM [compliance].[ExtractRun] AS r
    INNER JOIN [compliance].[ExtractControlTotal] AS c ON r.[ExtractRunId] = c.[ExtractRunId]
    WHERE c.[ControlCode] = 'FAILURES_TOTAL';

    SELECT TOP (0) a.[ExtractStatusCode], a.[ValidationStatusCode], a.[ExpectedValue], a.[ActualValue], a.[OutcomeCode]
    INTO #Expected
    FROM #Actual AS a;
    INSERT INTO #Expected ([ExtractStatusCode], [ValidationStatusCode], [ExpectedValue], [ActualValue], [OutcomeCode])
    VALUES ('SUCCEEDED', 'FAILED', 4.00, 3.00, 'FAIL');

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ComplianceTests].[test validation warns on unchecked rules and on prior-period changes over the limit]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRun';
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractControlTotal';
    EXEC tSQLt.FakeTable @TableName = N'compliance.ControlThreshold';

    INSERT INTO [compliance].[ExtractRun] ([ExtractRunId], [ExtractTypeCode], [PeriodStartDate], [ExtractStatusCode])
    VALUES (1, 'IPEDS_E12', '2024-07-01', 'SUCCEEDED'), (2, 'IPEDS_E12', '2025-07-01', 'GENERATING');
    INSERT INTO [compliance].[ControlThreshold] ([ExtractTypeCode], [ControlCode], [MaxChangePct])
    VALUES ('IPEDS_E12', 'TOTAL_HEADCOUNT', 20.00);
    INSERT INTO [compliance].[ExtractControlTotal] (
        [ExtractRunId], [ControlCode], [ControlKind], [ComparisonOperator], [ExpectedValue], [ActualValue]
    )
    VALUES
        (1, 'TOTAL_HEADCOUNT', 'RECONCILIATION', '=', 100, 100),
        (2, 'TOTAL_HEADCOUNT', 'RECONCILIATION', '=', 130, 130),
        (2, 'TOTAL_AT_LEAST_FALL_CENSUS', 'RULE', '>=', NULL, 130),
        (2, 'COMPLETERS_AT_MOST_AWARDS', 'RULE', '<=', 131, 131);

    EXEC [compliance].[usp_ValidateExtractControlTotals] @ExtractRunId = 2;

    SELECT c.[ControlCode], c.[PriorValue], c.[ChangePct], c.[OutcomeCode]
    INTO #Actual
    FROM [compliance].[ExtractControlTotal] AS c
    WHERE c.[ExtractRunId] = 2;
    SELECT TOP (0) a.[ControlCode], a.[PriorValue], a.[ChangePct], a.[OutcomeCode] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ControlCode], [PriorValue], [ChangePct], [OutcomeCode])
    VALUES
        ('TOTAL_HEADCOUNT', 100.00, 30.00, 'WARN'),
        ('TOTAL_AT_LEAST_FALL_CENSUS', NULL, NULL, 'WARN'),
        ('COMPLETERS_AT_MOST_AWARDS', NULL, NULL, 'PASS');
    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

    DECLARE @Status VARCHAR (15) = (SELECT r.[ValidationStatusCode] FROM [compliance].[ExtractRun] AS r WHERE r.[ExtractRunId] = 2);
    EXEC tSQLt.AssertEquals @Expected = 'WARNING', @Actual = @Status;
END;
GO

-- The builder error rolls back the generation transaction, which would end tSQLt's own.
--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [ComplianceTests].[test a builder error leaves a FAILED run with its message and no rows]
AS
BEGIN
    EXEC [ComplianceTests].[FakeGenerationContext];
    EXEC tSQLt.FakeTable @TableName = N'compliance.CensusSnapshot';
    DECLARE @RunId BIGINT;
    DECLARE @Error INT;

    BEGIN TRY
        EXEC [compliance].[usp_GenerateExtract]
            @ExtractTypeCode = 'ENROLLMENT_CENSUS', @ReportingPeriod = '2025FA', @ExtractRunId = @RunId OUTPUT, @ReturnSummary = 0;
    END TRY
    BEGIN CATCH
        SET @Error = ERROR_NUMBER();
    END CATCH;

    -- OUTPUT parameters are not returned when a procedure raises an error, so find the run by table.
    SET @RunId = (SELECT MAX(r.[ExtractRunId]) FROM [compliance].[ExtractRun] AS r);
    DECLARE @Status VARCHAR (15) = (SELECT r.[ExtractStatusCode] FROM [compliance].[ExtractRun] AS r WHERE r.[ExtractRunId] = @RunId);
    DECLARE @HasMessage BIT = (
        SELECT CASE WHEN r.[ErrorMessage] LIKE N'Error 52130:%' THEN 1 ELSE 0 END
        FROM [compliance].[ExtractRun] AS r
        WHERE r.[ExtractRunId] = @RunId
    );
    DECLARE @Rows INT = (SELECT COUNT(*) FROM [compliance].[ExtractRow]);

    EXEC tSQLt.AssertEquals @Expected = 52130, @Actual = @Error;
    EXEC tSQLt.AssertEquals @Expected = 'FAILED', @Actual = @Status;
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @HasMessage;
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @Rows;
END;
GO

--[@tSQLt:NoTransaction](DEFAULT)
CREATE PROCEDURE [ComplianceTests].[test an academic year must be two consecutive years]
AS
BEGIN
    EXEC [ComplianceTests].[FakeGenerationContext];

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52103;
    EXEC [compliance].[usp_GenerateExtract] @ExtractTypeCode = 'IPEDS_C', @ReportingPeriod = '2025-2027', @ReturnSummary = 0;
END;
GO

------------------------------------------------------------------------------------------
-- Approval
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ComplianceTests].[AddReviewableRun]
    @ValidationStatusCode VARCHAR (15) = 'PASSED',
    @RequestedBy          NVARCHAR (128) = N'some_other_user'
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRun';
    EXEC tSQLt.FakeTable @TableName = N'audit.AccessEvent', @Identity = 1, @Defaults = 1;
    INSERT INTO [compliance].[ExtractRun] ([ExtractRunId], [ExtractStatusCode], [ValidationStatusCode], [ApprovalStatusCode], [RequestedBy])
    VALUES (9, 'SUCCEEDED', @ValidationStatusCode, 'PENDING', @RequestedBy);
END;
GO

CREATE PROCEDURE [ComplianceTests].[test the requester cannot approve their own run]
AS
BEGIN
    DECLARE @Me NVARCHAR (128) = USER_NAME();
    EXEC [ComplianceTests].[AddReviewableRun] @RequestedBy = @Me;

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52114;
    EXEC [compliance].[usp_ApproveExtract] @ExtractRunId = 9;
END;
GO

CREATE PROCEDURE [ComplianceTests].[test a run that failed validation cannot be approved]
AS
BEGIN
    EXEC [ComplianceTests].[AddReviewableRun] @ValidationStatusCode = 'FAILED';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52113;
    EXEC [compliance].[usp_ApproveExtract] @ExtractRunId = 9;
END;
GO

CREATE PROCEDURE [ComplianceTests].[test approval records the reviewer and is audited]
AS
BEGIN
    EXEC [ComplianceTests].[AddReviewableRun] @ValidationStatusCode = 'WARNING';

    EXEC [compliance].[usp_ApproveExtract] @ExtractRunId = 9, @Note = N'Growth explained by the new Nursing cohort.';

    SELECT r.[ApprovalStatusCode], r.[ApprovedBy], e.[EventType], e.[IsAllowed]
    INTO #Actual
    FROM [compliance].[ExtractRun] AS r
    CROSS JOIN [audit].[AccessEvent] AS e;
    SELECT TOP (0) a.[ApprovalStatusCode], a.[ApprovedBy], a.[EventType], a.[IsAllowed] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([ApprovalStatusCode], [ApprovedBy], [EventType], [IsAllowed])
    VALUES ('APPROVED', USER_NAME(), 'EXTRACT_APPROVE', 1);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [ComplianceTests].[test the approval constraint rejects approving a failed run directly]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRun';
    EXEC tSQLt.ApplyConstraint @TableName = N'compliance.ExtractRun', @ConstraintName = N'CK_compliance_ExtractRun_Approval';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 547;
    INSERT INTO [compliance].[ExtractRun] (
        [ExtractRunId], [ExtractStatusCode], [ValidationStatusCode], [ApprovalStatusCode], [RequestedBy], [ApprovedBy], [ApprovedAtUtc]
    )
    VALUES (1, 'SUCCEEDED', 'FAILED', 'APPROVED', N'requester', N'reviewer', '2026-10-05');
END;
GO

------------------------------------------------------------------------------------------
-- Immutability
------------------------------------------------------------------------------------------
CREATE PROCEDURE [ComplianceTests].[test lines of a completed run cannot change]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRun';
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRow';
    INSERT INTO [compliance].[ExtractRun] ([ExtractRunId], [ExtractStatusCode]) VALUES (1, 'GENERATING');
    INSERT INTO [compliance].[ExtractRow] ([ExtractRunId], [LineNumber], [LineText]) VALUES (1, 1, N'A,B');
    UPDATE r SET r.[ExtractStatusCode] = 'SUCCEEDED' FROM [compliance].[ExtractRun] AS r;
    EXEC tSQLt.ApplyTrigger @TableName = N'compliance.ExtractRow', @TriggerName = N'trg_ExtractRow_Immutable';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52123;
    UPDATE r SET r.[LineText] = N'A,C' FROM [compliance].[ExtractRow] AS r;
END;
GO

CREATE PROCEDURE [ComplianceTests].[test a completed run's checksum cannot change]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRun';
    INSERT INTO [compliance].[ExtractRun] ([ExtractRunId], [ExtractStatusCode], [ApprovalStatusCode], [ContentSha256])
    VALUES (1, 'SUCCEEDED', 'PENDING', 0x01);
    EXEC tSQLt.ApplyTrigger @TableName = N'compliance.ExtractRun', @TriggerName = N'trg_ExtractRun_Immutable';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52121;
    UPDATE r SET r.[ContentSha256] = 0x02 FROM [compliance].[ExtractRun] AS r;
END;
GO

CREATE PROCEDURE [ComplianceTests].[test an approval decision is final]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRun';
    INSERT INTO [compliance].[ExtractRun] ([ExtractRunId], [ExtractStatusCode], [ApprovalStatusCode], [ApprovedBy])
    VALUES (1, 'SUCCEEDED', 'APPROVED', N'reviewer');
    EXEC tSQLt.ApplyTrigger @TableName = N'compliance.ExtractRun', @TriggerName = N'trg_ExtractRun_Immutable';

    EXEC tSQLt.ExpectException @ExpectedErrorNumber = 52122;
    UPDATE r SET r.[ApprovalStatusCode] = 'REJECTED' FROM [compliance].[ExtractRun] AS r;
END;
GO

CREATE PROCEDURE [ComplianceTests].[test a term period compares with the previous term of the same type]
AS
BEGIN
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractRun';
    EXEC tSQLt.FakeTable @TableName = N'compliance.ExtractControlTotal';
    EXEC tSQLt.FakeTable @TableName = N'compliance.ControlThreshold';

    INSERT INTO [compliance].[ExtractRun] ([ExtractRunId], [ExtractTypeCode], [ReportingPeriod], [PeriodStartDate], [ExtractStatusCode])
    VALUES
        (1, 'ENROLLMENT_CENSUS', '2025SU', '2025-06-01', 'SUCCEEDED'),
        (2, 'ENROLLMENT_CENSUS', '2026SP', '2026-01-20', 'SUCCEEDED'),
        (3, 'ENROLLMENT_CENSUS', '2026SU', '2026-06-01', 'GENERATING');
    INSERT INTO [compliance].[ExtractControlTotal] ([ExtractRunId], [ControlCode], [ControlKind], [ActualValue])
    VALUES (1, 'INCLUDED_COUNT', 'INFO', 73), (2, 'INCLUDED_COUNT', 'INFO', 990), (3, 'INCLUDED_COUNT', 'INFO', 124);

    EXEC [compliance].[usp_ValidateExtractControlTotals] @ExtractRunId = 3;

    DECLARE @PriorRun BIGINT = (SELECT c.[PriorExtractRunId] FROM [compliance].[ExtractControlTotal] AS c WHERE c.[ExtractRunId] = 3);
    EXEC tSQLt.AssertEquals @Expected = 1, @Actual = @PriorRun;
END;
GO

EXEC tSQLt.SetFakeViewOff @SchemaName = N'dq';
GO
