-- Extract boundary for Directory-Sim accounts with their groups as a sorted list.
CREATE VIEW [landing].[vw_SourceDirectoryAccount]
AS
SELECT
    da.[AccountGuid],
    da.[SamAccountName],
    da.[UserPrincipalName],
    da.[EmployeeId],
    da.[DisplayName],
    da.[AccountType],
    da.[IsEnabled],
    da.[WhenCreatedUtc],
    grp.[GroupNames],
    GREATEST(da.[UpdatedAtUtc], grp.[UpdatedAtUtc]) AS [SourceUpdatedAtUtc]
FROM [$(SourceSystems)].[DirectorySim].[DirectoryAccount] AS da
OUTER APPLY (
    SELECT
        CAST(STRING_AGG(CAST(gm.[GroupName] AS NVARCHAR (MAX)), N',') WITHIN GROUP (ORDER BY gm.[GroupName]) AS NVARCHAR (4000))
            AS [GroupNames],
        MAX(gm.[UpdatedAtUtc]) AS [UpdatedAtUtc]
    FROM [$(SourceSystems)].[DirectorySim].[GroupMembership] AS gm
    WHERE gm.[AccountGuid] = da.[AccountGuid]
) AS grp;
