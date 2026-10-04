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
PY_RUN = $(ODBC_ENV) $(UV) run

SOURCE_DACPAC := database/SourceSystems.Database/bin/$(CONFIGURATION)/SourceSystems.Database.dacpac
OPS_DACPAC := database/CampusDataOps.Database/bin/$(CONFIGURATION)/CampusDataOps.Database.dacpac

# sqlcmd reads the password from SQLCMDPASSWORD so it never appears in the argument list.
SQLCMD_RUN = SQLCMDPASSWORD="$$MSSQL_SA_PASSWORD" $(SQLCMD) -S "$(SQL_SERVER)" -U sa -C -b

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
		echo "Publishing $$database"; \
		$(SQLPACKAGE) /Action:Publish /Quiet:True \
			/SourceFile:"$$dacpac" \
			/TargetServerName:"$(SQL_SERVER)" /TargetDatabaseName:"$$database" \
			/TargetUser:sa /TargetPassword:"$$MSSQL_SA_PASSWORD" /TargetTrustServerCertificate:True \
			/p:BlockOnPossibleDataLoss=True; \
	done

.PHONY: seed
seed: ## Replace simulator source data with the deterministic synthetic dataset
	$(PY_RUN) campus-ops load-sources --seed $(SEED) --scale $(SCALE)

.PHONY: smoke
smoke: ## Run the post-deployment smoke test
	$(SQLCMD_RUN) -d CampusDataOps -i database/CampusDataOps.Database/Scripts/smoke_test.sql

.PHONY: bootstrap
bootstrap: check-tools up deploy seed smoke ## One command: start, build, deploy, seed and smoke test (rerunnable)
	@echo "Bootstrap complete"

.PHONY: test
test: ## Run Python tests that need no database
	$(UV) run pytest -m "not db"

.PHONY: test-db
test-db: ## Run Python tests against the deployed local database
	CAMPUS_RUN_DB_TESTS=1 $(PY_RUN) pytest -m db

.PHONY: lint
lint: ## Lint Python and SQL
	$(UV) run ruff check .
	$(UV) run ruff format --check .
	$(UV) run sqlfluff lint database

.PHONY: fmt
fmt: ## Format Python
	$(UV) run ruff check --fix .
	$(UV) run ruff format .
