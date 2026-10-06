# campus-data-hub developer commands. Run `make help` for the list.
# Secrets come from .env (git-ignored). Avoid '$' in MSSQL_SA_PASSWORD: make expands it.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

-include .env
export

MSSQL_PORT ?= 1433
SQL_SERVER := localhost,$(MSSQL_PORT)
CONFIGURATION ?= Debug
SQLPACKAGE ?= sqlpackage
SQLCMD ?= sqlcmd
UV ?= uv
SEED ?= 20260901
SCALE ?= 1.0
HEALTH_TIMEOUT_SECONDS ?= 240

# ODBC Driver 18 on macOS loads OpenSSL from Homebrew's unversioned "openssl" alias. When that
# alias points at OpenSSL 4 (unsupported by the driver), prefer the keg-only openssl@3 libraries.
ifeq ($(shell uname -s),Darwin)
OPENSSL3_LIB ?= $(shell brew --prefix openssl@3 2> /dev/null)/lib
ODBC_ENV := $(if $(wildcard $(OPENSSL3_LIB)/libssl.3.dylib),DYLD_LIBRARY_PATH="$(OPENSSL3_LIB)",)
endif
# Run modules with `python -m`: console-script launchers in long or spaced paths become
# /bin/sh trampolines, and macOS strips DYLD_* variables when executing /bin/sh.
PY_RUN = $(ODBC_ENV) $(UV) run python -m

# tSQLt is downloaded once into the git-ignored .tools/ folder and verified against a pinned
# SHA-256 before use. It is installed only into development and CI databases, never shipped.
TSQLT_VERSION := 1.0.8083.3529
TSQLT_DIR := .tools/tsqlt
TSQLT_ZIP := $(TSQLT_DIR)/tSQLt_V$(TSQLT_VERSION).zip
TSQLT_URL := https://tsqlt.org/wp-content/uploads/dlm_uploads/2015/07/tSQLt_V$(TSQLT_VERSION).zip
TSQLT_SHA256 := af841f357dd9189f8b197c34c5014fe0dbabd3be34b024ed46967dafe13d4f50
SQL_TESTS_DIR := database/CampusDataOps.Tests

SOURCE_DACPAC := database/SourceSystems.Database/bin/$(CONFIGURATION)/SourceSystems.Database.dacpac
OPS_DACPAC := database/CampusDataOps.Database/bin/$(CONFIGURATION)/CampusDataOps.Database.dacpac

# sqlcmd reads the password from SQLCMDPASSWORD so it never appears in the argument list.
# -I sets QUOTED_IDENTIFIER ON: the classic ODBC sqlcmd (used in CI) defaults it OFF, and
# procedures created that way (the tSQLt tests) cannot write to tables with filtered indexes.
SQLCMD_RUN = SQLCMDPASSWORD="$$MSSQL_SA_PASSWORD" $(SQLCMD) -S "$(SQL_SERVER)" -U sa -C -b -I

.PHONY: help
help: ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: check-tools
check-tools: ## Verify required local tools and .env
	@for tool in docker dotnet $(UV) $(SQLCMD) $(firstword $(SQLPACKAGE)); do \
		command -v "$$tool" > /dev/null || { echo "Missing tool: $$tool (see README prerequisites)"; exit 1; }; \
	done
	@test -f .env || { echo "Missing .env: copy .env.example to .env and set MSSQL_SA_PASSWORD"; exit 1; }
	@test -n "$${MSSQL_SA_PASSWORD:-}" || { echo "MSSQL_SA_PASSWORD is empty in .env"; exit 1; }
	@echo "Tools and .env OK"

.PHONY: up
up: ## Start SQL Server and wait until it is healthy
	docker compose up -d
	@$(MAKE) --no-print-directory wait

.PHONY: wait
wait:
	@echo "Waiting for SQL Server to report healthy (up to $(HEALTH_TIMEOUT_SECONDS)s)..."
	@for ((i = 0; i < $(HEALTH_TIMEOUT_SECONDS); i += 5)); do \
		status=$$(docker inspect -f '{{.State.Health.Status}}' campus-data-hub-sql 2> /dev/null || echo missing); \
		if [[ "$$status" == "healthy" ]]; then echo "SQL Server is healthy"; exit 0; fi; \
		sleep 5; \
	done; \
	echo "SQL Server did not become healthy; run: docker compose logs sqlserver"; exit 1

.PHONY: down
down: ## Stop SQL Server (data volume is kept)
	docker compose down

.PHONY: clean
clean: ## Stop SQL Server and DELETE its data volume (requires CONFIRM=1)
	@test "$(CONFIRM)" = "1" || { echo "This deletes all local database data. Re-run with CONFIRM=1"; exit 1; }
	docker compose down -v
	dotnet clean campus-data-hub.sln -nologo -v q

.PHONY: build
build: ## Build both SQL projects into DACPACs
	dotnet build campus-data-hub.sln -c $(CONFIGURATION) -nologo -v q

.PHONY: deploy
deploy: build ## Publish both DACPACs to the local SQL Server
	@for pair in "$(SOURCE_DACPAC):SourceSystems" "$(OPS_DACPAC):CampusDataOps"; do \
		dacpac="$${pair%%:*}"; database="$${pair##*:}"; \
		variables=""; \
		if [[ "$$database" == "CampusDataOps" ]]; then variables="/v:SourceSystems=SourceSystems"; fi; \
		echo "Publishing $$database"; \
		$(SQLPACKAGE) /Action:Publish /Quiet:True \
			/SourceFile:"$$dacpac" \
			/TargetServerName:"$(SQL_SERVER)" /TargetDatabaseName:"$$database" \
			/TargetUser:sa /TargetPassword:"$$MSSQL_SA_PASSWORD" /TargetTrustServerCertificate:True \
			/p:BlockOnPossibleDataLoss=True $$variables; \
	done

.PHONY: seed
seed: ## Replace simulator source data with the deterministic synthetic dataset
	$(PY_RUN) campus_ops.cli load-sources --seed $(SEED) --scale $(SCALE)

.PHONY: smoke
smoke: ## Run the post-deployment smoke test
	$(SQLCMD_RUN) -d CampusDataOps -i database/CampusDataOps.Database/Scripts/smoke_test.sql

.PHONY: nightly
nightly: ## Run the nightly integration pipeline once (same procedures as the Agent job)
	$(PY_RUN) campus_ops.cli nightly

.PHONY: recover
recover: ## Resume a failed run: make recover FAILED_BATCH=<id> AT=<STEP>
	@test -n "$(FAILED_BATCH)" -a -n "$(AT)" || { echo "Usage: make recover FAILED_BATCH=<batch id> AT=<step code>"; exit 1; }
	$(PY_RUN) campus_ops.cli recover --failed-batch $(FAILED_BATCH) --at $(AT)

.PHONY: extracts
extracts: ## Run the CENSUS, DAILY and WEEKLY extract schedules now (same procedure as the Agent jobs)
	$(PY_RUN) campus_ops.cli run-schedule --code CENSUS
	$(PY_RUN) campus_ops.cli run-schedule --code DAILY
	$(PY_RUN) campus_ops.cli run-schedule --code WEEKLY

.PHONY: export
export: ## Write a stored extract run to out/extracts: make export RUN=<id> [PUBLIC=1 for sample-output]
	@test -n "$(RUN)" || { echo "Usage: make export RUN=<extract run id> [PUBLIC=1]"; exit 1; }
	$(PY_RUN) campus_ops.cli export --run $(RUN) $(if $(filter 1,$(PUBLIC)),--public,)

.PHONY: agent-install
agent-install: ## Create or replace the SQL Server Agent nightly integration job
	$(SQLCMD_RUN) -d msdb -i automation/sql-agent/01_create_nightly_integration_job.sql

.PHONY: agent-run
agent-run: ## Start the Agent job, wait for it and fail if it fails
	$(SQLCMD_RUN) -d msdb -i automation/sql-agent/02_run_nightly_integration_job.sql

.PHONY: reset-ops
reset-ops: ## DEVELOPMENT ONLY: delete all CampusDataOps operational data (requires CONFIRM=1)
	@test "$(CONFIRM)" = "1" || { echo "This deletes all landing, staging, integration, quality and audit rows. Re-run with CONFIRM=1"; exit 1; }
	$(SQLCMD_RUN) -d CampusDataOps -v ConfirmReset=YES -i database/CampusDataOps.Database/Scripts/reset_operational_data.sql

.PHONY: bootstrap
bootstrap: check-tools up deploy seed smoke ## One command: start, build, deploy, seed and smoke test (rerunnable)
	@echo "Bootstrap complete"

.PHONY: test
test: ## Run Python tests that need no database
	$(UV) run pytest -m "not db"

.PHONY: test-db
test-db: ## Run Python tests against the deployed local database
	CAMPUS_RUN_DB_TESTS=1 $(PY_RUN) pytest -m db

$(TSQLT_ZIP):
	mkdir -p $(TSQLT_DIR)
	curl -fsSL -o "$@.part" "$(TSQLT_URL)"
	echo "$(TSQLT_SHA256)  $@.part" | shasum -a 256 -c -
	mv "$@.part" "$@"
	cd $(TSQLT_DIR) && unzip -o -q "$(notdir $@)" PrepareServer.sql tSQLt.class.sql License.txt

.PHONY: tsqlt-install
tsqlt-install: $(TSQLT_ZIP) ## Install tSQLt into the local CampusDataOps database (development and CI only)
	@installed=$$($(SQLCMD_RUN) -d CampusDataOps -h -1 -W -Q "SET NOCOUNT ON; IF OBJECT_ID('tSQLt.Info') IS NOT NULL SELECT Version FROM tSQLt.Info();" | tr -d '[:space:]'); \
	if [[ "$$installed" == "$(TSQLT_VERSION)" ]]; then echo "tSQLt $$installed already installed"; else \
		$(SQLCMD_RUN) -d master -i $(TSQLT_DIR)/PrepareServer.sql > /dev/null; \
		$(SQLCMD_RUN) -d CampusDataOps -i $(TSQLT_DIR)/tSQLt.class.sql > /dev/null; \
		echo "tSQLt $(TSQLT_VERSION) installed"; \
	fi

.PHONY: test-sql
# -y 0 keeps the XML untruncated; the classic sqlcmd cannot combine it with -h -1, so the column
# header is stripped by keeping output from the first line that starts with '<'.
test-sql: tsqlt-install ## Run the tSQLt database unit tests (writes out/tsqlt-results.xml)
	@for file in $(SQL_TESTS_DIR)/Tests/*.sql; do \
		$(SQLCMD_RUN) -d CampusDataOps -i "$$file" | grep -v "^$$" || [[ $${PIPESTATUS[0]} -eq 0 ]] || { echo "Failed to create tests in $$file"; exit 1; }; \
	done
	@mkdir -p out; status=0; \
	$(SQLCMD_RUN) -d CampusDataOps -Q "EXEC tSQLt.RunAll;" || status=$$?; \
	$(SQLCMD_RUN) -d CampusDataOps -y 0 -Q "SET NOCOUNT ON; EXEC tSQLt.XmlResultFormatter;" | sed -n '/^</,$$p' > out/tsqlt-results.xml; \
	exit $$status

.PHONY: lint
lint: ## Lint Python and SQL
	$(UV) run ruff check .
	$(UV) run ruff format --check .
	$(UV) run sqlfluff lint database automation

.PHONY: fmt
fmt: ## Format Python
	$(UV) run ruff check --fix .
	$(UV) run ruff format .
