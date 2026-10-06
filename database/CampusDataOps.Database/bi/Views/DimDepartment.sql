-- Power BI department dimension: the offices that own measures, rules and exceptions.
CREATE VIEW [bi].[DimDepartment]
AS
SELECT d.[DepartmentCode], d.[DepartmentName]
FROM [reference].[Department] AS d;
