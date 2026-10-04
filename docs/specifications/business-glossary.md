# Business glossary

Definitions used across the database, code and reports. Entries marked **Assumption** are project
decisions that a real institution's Registrar or Institutional Research office would need to
confirm.

| Term | Definition | Where it lives |
|---|---|---|
| Academic year | July-to-June style year labelled `YYYY-YYYY`, beginning with the fall term. **Assumption:** summer belongs to the academic year of the *preceding* fall (Summer 2025 is in 2024-2025). | `reference.AcademicTerm.AcademicYear`, `J1Sim.AcademicTerm.AcademicYear` |
| Admitted applicant | An application whose current status is `ADMITTED` or `DEPOSITED`. Only these are queued for export to the SIS. | `SlateSim.Application.CurrentStatus`, `SlateSim.ExportQueue` |
| Aid year | Financial-aid year an award belongs to; equal to the term's academic year. | `J1Sim.FinancialAidAward.AidYear` |
| Applicant | A person record in the admissions CRM. May or may not already exist in the SIS. | `SlateSim.Person` |
| Application | One request for admission to one entry term. Status moves `STARTED → SUBMITTED → COMPLETE → ADMITTED/DENIED → DEPOSITED`, or to `WITHDRAWN` after submission. | `SlateSim.Application`, `SlateSim.ApplicationStatusHistory` |
| Batch | One execution of a process, such as a landing load for one source. Identified by `BatchId` and audited with status, timing, counts and watermarks. | `audit.BatchRun` |
| Billed credits | Credit hours a student is charged for in a term: registered plus withdrawn sections; dropped sections are not billed. | Generator logic; `J1Sim.StudentAccountTransaction` (`TUIT`) |
| Census date | The date on which official term enrollment is counted. **Assumption:** 14 days after the start of fall and spring terms and 7 days after the start of summer. | `reference.AcademicTerm.CensusDate` |
| Control totals | Counts that must reconcile. For a successful landing batch: rows read = inserted + unchanged + rejected. | `landing.usp_EndLandingBatch` |
| Credential | A certificate or associate degree awarded on completing a program's required credits. | `J1Sim.CredentialAwarded` |
| Crosswalk (program) | The governed mapping from an admissions program code to an SIS program code. | `reference.ProgramCrosswalk` |
| Directory account | An identity record. Student accounts carry the SIS `IdNumber` in `EmployeeId`; staff and service accounts do not. | `DirectorySim.DirectoryAccount` |
| Disbursed amount | Aid actually paid to the student account. **Assumption:** disbursement occurs 7 days after census, so a term whose census has not passed has nothing disbursed. | `J1Sim.FinancialAidAward.DisbursedAmount` |
| Earned credits | Credits from sections graded D or better. Used to decide program completion. | Generator logic over `J1Sim.FinalGrade` |
| Edge case | A deliberately planted scenario with fixed identifiers, used to prove integration and data-quality handling. | `pipelines/campus_ops/generators/edge_cases.py` |
| Entry term | The term an applicant intends to start, or a student started. | `SlateSim.Application.EntryTermCode`, `J1Sim.Student.EntryTermCode` |
| Exception reason | A managed category for records integration cannot process automatically, with owner, severity and remediation guidance. | `reference.ExceptionReason` |
| Full-time | 12 or more credit hours in a fall or spring term. Used by the generator to prorate aid; reporting definitions follow in Part 3. | `financial_aid.FULL_TIME_CREDITS` |
| IdNumber | The SIS's 7-digit institutional identifier for a person. Regular synthetic people start at 2400001; 9000000-9000099 is reserved for edge cases. | `J1Sim.Person.IdNumber` |
| Idempotent | Running an operation again with the same input leaves the same end state, without duplicates. Required of deploys, seeds and (from Part 2) batch loads. | Throughout |
| Landing | The append-only layer that stores source rows exactly as received with batch metadata. See ADR-002. | `landing` schema |
| Matriculation | A person becoming an SIS student in a program. | `J1Sim.Student.MatriculationDate` |
| Open for admission | Whether applications may target a term. | `reference.AcademicTerm.IsOpenForAdmission` |
| Simulation date (AS_OF) | The fixed "today" of the synthetic dataset: 2026-09-01 12:00 UTC. Nothing is generated after it, and Fall 2026 is registered but not yet started. | `generators/common.py` |
| Source watermark | The highest source `UpdatedAtUtc` a successful landing batch has read. The next batch reads rows changed after it. Never moves backwards; failed batches never advance it. | `audit.BatchRun.SourceWatermarkUtc` |
| Student status | `ACTIVE` (enrolled or registered for the current term), `INACTIVE` (stopped out), `WITHDRAWN` (left the institution), `GRADUATED` (credential awarded). | `J1Sim.Student.StudentStatus` |
