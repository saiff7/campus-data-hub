-- One RFC 4180 CSV field (docs/specifications/extract-controls.md): NULL becomes empty; a value
-- containing a comma, double quote, carriage return or line feed is quoted, with inner quotes
-- doubled. Callers convert numbers and dates to text first (decimals keep their declared scale,
-- dates use style 23, YYYY-MM-DD).
CREATE FUNCTION [compliance].[fn_CsvField] (@Value NVARCHAR (4000))
RETURNS NVARCHAR (4000)
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
        WHEN @Value IS NULL THEN N''
        WHEN CHARINDEX(N',', @Value) > 0 OR CHARINDEX(N'"', @Value) > 0
            OR CHARINDEX(NCHAR(13), @Value) > 0 OR CHARINDEX(NCHAR(10), @Value) > 0
            THEN CONCAT(N'"', REPLACE(@Value, N'"', N'""'), N'"')
        ELSE @Value
    END;
END;
