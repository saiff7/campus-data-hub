-- Power BI data-quality rule dimension.
CREATE VIEW [bi].[DimDataQualityRule]
AS
SELECT
    r.[RuleCode],
    r.[Description],
    r.[EntityName],
    r.[Severity],
    r.[OwnerDepartment],
    r.[IsActive]
FROM [dq].[Rule] AS r;
