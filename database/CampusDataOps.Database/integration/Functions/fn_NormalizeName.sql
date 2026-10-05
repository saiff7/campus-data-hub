-- Matching normalization for names (docs/specifications/matching-rules.md): tabs and line
-- breaks become spaces, runs of spaces collapse to one, the result is trimmed and upper-cased.
-- Punctuation and accents are kept on purpose. Used only when staging writes a row; match
-- joins compare the stored result. Written without loops so SQL Server can inline it.
CREATE FUNCTION [integration].[fn_NormalizeName] (@Value NVARCHAR (100))
RETURNS NVARCHAR (100)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @Spaced NVARCHAR (100) = REPLACE(REPLACE(REPLACE(@Value, NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ');

    -- Collapse runs of spaces: mark each space as "space + \x01", remove "\x01 + space" pairs,
    -- then drop the remaining markers. \x01 cannot occur in a typed name.
    DECLARE @Collapsed NVARCHAR (200) = REPLACE(
        REPLACE(REPLACE(@Spaced, N' ', N' ' + NCHAR(1)), NCHAR(1) + N' ', N''),
        NCHAR(1),
        N''
    );

    RETURN NULLIF(UPPER(TRIM(@Collapsed)), N'');
END;
