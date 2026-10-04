/*
Post-deployment script for CampusDataOps. Runs after every publish, so every included
script must be idempotent.
*/
:r ./reference/Seed/reference_seed.sql
