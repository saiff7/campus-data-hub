/*
Post-deployment script for CampusDataOps. Runs after every publish, so every included
script must be idempotent. Order matters: later seeds reference earlier ones. GO separates
the seeds so each declares its own variables in its own batch.
*/
:r ./reference/Seed/reference_seed.sql
GO
:r ./reference/Seed/integration_reference_seed.sql
GO
:r ./reference/Seed/reporting_reference_seed.sql
GO
:r ./dq/Seed/dq_rule_seed.sql
GO
