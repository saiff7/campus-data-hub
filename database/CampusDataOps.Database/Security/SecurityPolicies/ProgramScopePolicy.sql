-- Filters census snapshot rows to the caller's programs for program coordinators. No block
-- predicate: no role may write to the table and triggers make it immutable.
CREATE SECURITY POLICY [security].[ProgramScopePolicy]
ADD FILTER PREDICATE [security].[fn_ProgramScopePredicate]([ProgramCode]) ON [compliance].[CensusSnapshotEnrollment]
WITH (STATE = ON, SCHEMABINDING = ON);
