# Runbook: access request

**Owner:** the security office (approves), with `role_security_admin` members (apply)
**Applies to:** granting, changing or removing a person's or service's access to CampusDataOps
([security model](../architecture/security-model.md))

## 1. Approve the request

The request names the person, the role and the business reason (legitimate educational
interest, for student records). It also names any programs, if the role is
`role_program_coordinator`. The security office approves it in the ticketing system; the
ticket reference is required by every procedure below.

| Need | Role |
|---|---|
| Census and academic progress (Registrar, Enrollment Management) | `role_enrollment_reporter` |
| Aid packaging | `role_financial_aid_reporter` |
| Account aging | `role_student_accounts_reporter` |
| Leadership KPIs, IPEDS-aligned extracts, approvals, Power BI refresh | `role_ir_analyst` |
| Masked census roster for own programs | `role_program_coordinator` plus program scope |
| Exception work and drill-through, pipeline operation | `role_integration_service` |
| Audit and permission review | `role_auditor` |

`role_security_admin` itself is granted only by `db_owner`, and never through this runbook.

## 2. Create the database user (database administrator)

Server logins and authentication are outside this repository. A DBA creates the login, using
Microsoft Entra ID or Windows authentication in production, then:

```sql
USE CampusDataOps;
CREATE USER [jdoe] FOR LOGIN [CAMPUS\jdoe];
```

## 3. Grant the role (security administrator)

```sql
EXEC security.usp_GrantRoleMembership @UserName = N'jdoe', @RoleName = N'role_enrollment_reporter',
     @TicketReference = N'ACC-1234';
```

For a program coordinator, also set the programs, one row per program:

```sql
EXEC security.usp_SetProgramScope @UserName = N'jdoe', @ProgramCode = 'NURS.AS', @IsGranted = 1,
     @TicketReference = N'ACC-1234';
```

A coordinator with no scope sees an empty roster, not an error. Always check step 4.

## 4. Verify

```sql
SELECT r.name AS RoleName FROM sys.database_role_members AS m
JOIN sys.database_principals AS r ON r.principal_id = m.role_principal_id
WHERE m.member_principal_id = DATABASE_PRINCIPAL_ID(N'jdoe');

EXECUTE AS USER = N'jdoe';
SELECT COUNT(*) FROM reporting.vw_EnrollmentCensus;   -- succeeds for enrollment reporters
SELECT TOP (0) * FROM staging.Person;                 -- must fail with error 229
REVERT;
```

## 5. Remove or change access

Run `security.usp_RevokeRoleMembership` (same parameters), and
`security.usp_SetProgramScope ... @IsGranted = 0` for each program. When someone changes jobs,
revoke the old role before granting the new one.

## 6. Review (quarterly, `role_auditor`)

```sql
-- Who holds which role
SELECT r.name AS RoleName, u.name AS UserName
FROM sys.database_role_members AS m
JOIN sys.database_principals AS r ON r.principal_id = m.role_principal_id
JOIN sys.database_principals AS u ON u.principal_id = m.member_principal_id
WHERE r.name LIKE N'role[_]%' ORDER BY r.name, u.name;

-- Every permission change, including any made outside the procedures
SELECT EventType, LoginName, UserName, ObjectName, Permissions, Grantees, OccurredAtUtc
FROM audit.PermissionChangeEvent WHERE OccurredAtUtc >= DATEADD(MONTH, -3, SYSUTCDATETIME())
ORDER BY OccurredAtUtc;

-- Deployed permissions; tSQLt SecurityTests compares them with the specified matrix
SELECT * FROM security.vw_RolePermissionMatrix ORDER BY RoleName, SecurableName;
```

Investigate any `ADD_ROLE_MEMBER` without a matching `ROLE_GRANT` row in `audit.AccessEvent`: a
security admin used their `ALTER` permission directly instead of the audited procedure.
