-- Power BI exception reason dimension.
CREATE VIEW [bi].[DimExceptionReason]
AS
SELECT
    r.[ExceptionReasonCode],
    r.[Description],
    r.[Category],
    r.[DefaultSeverity],
    r.[OwnerDepartment],
    r.[BlocksProcessing]
FROM [reference].[ExceptionReason] AS r;
