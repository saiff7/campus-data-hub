-- Matching normalization for phone numbers (docs/specifications/matching-rules.md). Removes
-- spaces, hyphens, dots, parentheses and a leading +, drops a leading 1 from 11 digits, and
-- returns the 10-digit number, or NULL for anything else (letters, extensions, wrong length).
CREATE FUNCTION [integration].[fn_NormalizePhone] (@Value NVARCHAR (320))
RETURNS VARCHAR (10)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @Trimmed NVARCHAR (320) = TRIM(@Value);
    DECLARE @Digits NVARCHAR (320) = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        CASE WHEN LEFT(@Trimmed, 1) = N'+' THEN STUFF(@Trimmed, 1, 1, N'') ELSE @Trimmed END,
        N' ', N''), N'-', N''), N'.', N''), N'(', N''), N')', N'');

    RETURN CASE
        WHEN NULLIF(@Digits, N'') IS NULL OR @Digits LIKE N'%[^0-9]%' THEN NULL
        WHEN LEN(@Digits) = 10 THEN CAST(@Digits AS VARCHAR (10))
        WHEN LEN(@Digits) = 11 AND LEFT(@Digits, 1) = N'1' THEN CAST(RIGHT(@Digits, 10) AS VARCHAR (10))
    END;
END;
