-- Matching normalization for email (docs/specifications/matching-rules.md). Returns the
-- trimmed, lower-cased address when it is well formed, otherwise NULL; callers keep the raw
-- value and derive IsEmailValid from "raw present but normalized NULL". The checks are
-- structural only: exactly one @, a non-empty local part, a domain containing a dot that
-- neither starts nor ends with one, no whitespace and no consecutive dots.
CREATE FUNCTION [integration].[fn_NormalizeEmail] (@Value NVARCHAR (320))
RETURNS NVARCHAR (320)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @Email NVARCHAR (320) = LOWER(TRIM(@Value));
    DECLARE @At INT = CHARINDEX(N'@', @Email);
    DECLARE @Domain NVARCHAR (320) = CASE WHEN @At > 0 THEN SUBSTRING(@Email, @At + 1, 320) END;

    RETURN CASE
        WHEN NULLIF(@Email, N'') IS NULL THEN NULL
        WHEN LEN(@Email) - LEN(REPLACE(@Email, N'@', N'')) <> 1 THEN NULL
        WHEN @At = 1 THEN NULL
        WHEN @Email LIKE N'%[ ' + NCHAR(9) + NCHAR(10) + NCHAR(13) + N']%' THEN NULL
        WHEN CHARINDEX(N'..', @Email) > 0 THEN NULL
        WHEN CHARINDEX(N'.', @Domain) = 0 THEN NULL
        WHEN LEFT(@Domain, 1) = N'.' OR RIGHT(@Domain, 1) = N'.' THEN NULL
        ELSE @Email
    END;
END;
