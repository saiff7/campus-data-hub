/*
tSQLt tests for the normalization functions (docs/specifications/matching-rules.md).
*/
EXEC tSQLt.NewTestClass @ClassName = N'NormalizationTests';
GO

CREATE PROCEDURE [NormalizationTests].[test names are trimmed, whitespace-collapsed and upper-cased]
AS
BEGIN
    SELECT
        v.[Raw],
        [integration].[fn_NormalizeName](v.[Raw]) AS [Normalized]
    INTO #Actual
    FROM (
        VALUES
            (N'  riley  '),
            (N'Mary   Ann'),
            (N'Mary' + NCHAR(9) + N'Ann'),
            (N'O''Brien'),
            (N'José'),
            (N'   '),
            (CAST(NULL AS NVARCHAR (100)))
    ) AS v ([Raw]);

    SELECT TOP (0) a.[Raw], a.[Normalized] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([Raw], [Normalized])
    VALUES
        (N'  riley  ', N'RILEY'),
        (N'Mary   Ann', N'MARY ANN'),
        (N'Mary' + NCHAR(9) + N'Ann', N'MARY ANN'),
        (N'O''Brien', N'O''BRIEN'),
        (N'José', N'JOSÉ'),
        (N'   ', NULL),
        (NULL, NULL);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO

CREATE PROCEDURE [NormalizationTests].[test well-formed emails are trimmed and lower-cased]
AS
BEGIN
    DECLARE @Normalized NVARCHAR (320) = [integration].[fn_NormalizeEmail](N'  Okafor.Family@Example.COM ');
    EXEC tSQLt.AssertEquals @Expected = N'okafor.family@example.com', @Actual = @Normalized;
END;
GO

CREATE PROCEDURE [NormalizationTests].[test malformed emails normalize to NULL]
AS
BEGIN
    SELECT
        v.[Raw],
        [integration].[fn_NormalizeEmail](v.[Raw]) AS [Normalized]
    INTO #Actual
    FROM (
        VALUES
            (N'casey.rivera@@example.com'),
            (N'no-at-sign.example.com'),
            (N'@example.com'),
            (N'casey@example'),
            (N'casey@.example.com'),
            (N'casey@example.com.'),
            (N'casey..rivera@example.com'),
            (N'casey rivera@example.com'),
            (N'')
    ) AS v ([Raw]);

    DECLARE @NotNull INT = (SELECT COUNT(*) FROM #Actual AS a WHERE a.[Normalized] IS NOT NULL);
    EXEC tSQLt.AssertEquals @Expected = 0, @Actual = @NotNull;
END;
GO

CREATE PROCEDURE [NormalizationTests].[test phones reduce to ten digits or NULL]
AS
BEGIN
    SELECT
        v.[Raw],
        [integration].[fn_NormalizePhone](v.[Raw]) AS [Normalized]
    INTO #Actual
    FROM (
        VALUES
            (N'508-555-0142'),
            (N'(508) 555.0142'),
            (N'+1 508 555 0142'),
            (N'15085550142'),
            (N'555-0142'),
            (N'508-555-0142 x12'),
            (N'25085550142'),
            (N'')
    ) AS v ([Raw]);

    SELECT TOP (0) a.[Raw], a.[Normalized] INTO #Expected FROM #Actual AS a;
    INSERT INTO #Expected ([Raw], [Normalized])
    VALUES
        (N'508-555-0142', '5085550142'),
        (N'(508) 555.0142', '5085550142'),
        (N'+1 508 555 0142', '5085550142'),
        (N'15085550142', '5085550142'),
        (N'555-0142', NULL),
        (N'508-555-0142 x12', NULL),
        (N'25085550142', NULL),
        (N'', NULL);

    EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';
END;
GO
