# Build configuration
# -------------------

APP_NAME := `sed -n 's/^ *name.*=.*"\([^"]*\)".*/\1/p' pyproject.toml | head -1`
APP_VERSION := `sed -n 's/^ *version.*=.*"\([^"]*\)".*/\1/p' pyproject.toml | head -1`
GIT_REVISION = `git rev-parse HEAD`

# Introspection targets
# ---------------------

.PHONY: help
help: header targets

.PHONY: header
header:
	@echo "\033[34mEnvironment\033[0m"
	@echo "\033[34m---------------------------------------------------------------\033[0m"
	@printf "\033[33m%-23s\033[0m" "APP_NAME"
	@printf "\033[35m%s\033[0m" $(APP_NAME)
	@echo ""
	@printf "\033[33m%-23s\033[0m" "APP_VERSION"
	@printf "\033[35m%s\033[0m" $(APP_VERSION)
	@echo ""
	@printf "\033[33m%-23s\033[0m" "GIT_REVISION"
	@printf "\033[35m%s\033[0m" $(GIT_REVISION)
	@echo "\n"

.PHONY: targets
targets:
	@echo "\033[34mDevelopment Targets\033[0m"
	@echo "\033[34m---------------------------------------------------------------\033[0m"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

# Development targets
# -------------

.PHONY: install
install: ## Install dependencies
	uv sync

.PHONY: run
run: start

.PHONY: start
start: ## Starts the server
	$(eval include .env)
	$(eval export $(sh sed 's/=.*//' .env))

	uv run python main.py

.PHONY: migrate
migrate: ## Run the migrations
	$(eval include .env)
	$(eval export $(sh sed 's/=.*//' .env))

	uv run alembic upgrade head

.PHONY: rollback
rollback: ## Rollback migrations one level
	$(eval include .env)
	$(eval export $(sh sed 's/=.*//' .env))

	uv run alembic downgrade -1

.PHONY: reset-database
reset-database: ## Rollback all migrations
	$(eval include .env)
	$(eval export $(sh sed 's/=.*//' .env))

	uv run alembic downgrade base

.PHONY: generate-migration
generate-migration: ## Generate a new migration
	$(eval include .env)
	$(eval export $(sh sed 's/=.*//' .env))

	@read -p "Enter migration message: " message; \
	uv run alembic revision --autogenerate -m "$$message"

.PHONY: celery-worker
celery-worker: ## Start celery worker
	$(eval include .env)
	$(eval export $(sh sed 's/=.*//' .env))

	uv run celery -A worker worker --loglevel=info

# Check, lint and format targets
# ------------------------------

.PHONY: check
check: check-format lint

.PHONY: check-format
check-format: ## Dry-run code formatter
	uv run black ./ --check
	uv run isort ./ --profile black --check

.PHONY: lint
lint: ## Run linter
	uv run pylint ./api ./app ./core

.PHONY: format
format: ## Run code formatter
	uv run black .
	uv run isort .

.PHONY: check-lockfile
check-lockfile: ## Compares lock file with pyproject.toml
	uv lock --check

.PHONY: test
test: ## Run the test suite
	$(eval include .env)
	$(eval export $(sh sed 's/=.*//' .env))

	uv run pytest -vv -s --cache-clear ./

# Cleanup targets
# ------------------------------

.PHONY: clean
clean: ## Clean all cache, temporary files, and build artifacts
	@echo "Cleaning Python cache files..."
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.py~" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "*.egg" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleaning build artifacts..."
	rm -rf build/ dist/ .eggs/
	@echo "Clean complete!"

.PHONY: clean-docker
clean-docker: ## Remove Docker containers, volumes, and networks
	@echo "Stopping and removing Docker containers..."
	docker compose down -v
	@echo "Removing Docker volumes..."
	docker volume prune -f
	@echo "Docker cleanup complete!"

.PHONY: clean-db
clean-db: ## Remove local database data directories
	@echo "Removing database data directories..."
	rm -rf pgdata/
	rm -rf postgresql-test/
	@echo "Database data cleanup complete!"

.PHONY: clean-all
clean-all: clean clean-docker clean-db ## Clean everything (cache, Docker, and database data)
	@echo "Full cleanup complete!"