.DEFAULT_GOAL := help

.PHONY: help setup env db-up db-down db-wait db-ui db-ui-down db-backup db-restore \
	install migrate up down stop backend frontend dev build db-wipe

PYTHON := .venv/bin/python
PIP := .venv/bin/pip
DJANGO := $(PYTHON) backend/manage.py
BACKUP_DIR := db/backups

help:
	@echo "Study Tracker"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  make help        Show this help"
	@echo "  make up          Start Postgres, install, migrate, run Django + Next"
	@echo "  make stop        Stop Next + Django only (Postgres data untouched)"
	@echo "  make down        Stop Postgres container (keeps data volume)"
	@echo "  make setup       Env + Postgres + install + migrate (no servers)"
	@echo "  make backend     Run Django API on :8000"
	@echo "  make frontend    Run Next.js on :3000"
	@echo "  make migrate     Apply Django migrations"
	@echo "  make db-ui       Start Postgres (if needed) + pgAdmin on :5050"
	@echo "  make db-ui-down  Stop pgAdmin"
	@echo "  make db-backup   Dump database to db/backups/"
	@echo "  make db-restore  Restore dump (FILE=db/backups/....sql)"
	@echo "  make db-wipe     DANGER: delete DB volume (requires CONFIRM=YES)"
	@echo ""
	@echo "No make target deletes database data unless you run db-wipe CONFIRM=YES."
	@echo "Backup/restore docs: db/BACKUP.md"

setup: env db-up db-wait install migrate
	@echo "Ready. Run: make up"

up: setup
	$(MAKE) -j2 backend frontend

# Stop app servers only. Never touches Postgres or volumes.
stop:
	@echo "Stopping Next (:3000) and Django (:8000)..."
	@-lsof -tiTCP:3000 -sTCP:LISTEN | xargs kill 2>/dev/null || true
	@-lsof -tiTCP:8000 -sTCP:LISTEN | xargs kill 2>/dev/null || true
	@docker compose -f db/docker-compose.yml stop 2>/dev/null || true
	@echo "Stopped web app. Postgres left running (data preserved)."

# Stop Postgres container without removing the named volume.
down: db-down

env:
	@test -f .env || cp .env.example .env
	@echo ".env ready"

db-up:
	docker compose up -d

# stop = keep container/volume; never use "down -v" here
db-down:
	docker compose stop

db-ui: db-up db-wait
	docker compose -f db/docker-compose.yml up -d
	@echo "pgAdmin: http://localhost:5050  (admin@example.com / admin)"

db-ui-down:
	docker compose -f db/docker-compose.yml stop

db-backup: db-up db-wait
	@mkdir -p $(BACKUP_DIR)
	@file="$(BACKUP_DIR)/study_time_$$(date +%Y-%m-%d_%H%M%S).sql"; \
	docker compose exec -T postgres pg_dump -U study -d study_time --clean --if-exists > "$$file"; \
	echo "Backup written: $$file"

db-restore: db-up db-wait
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make db-restore FILE=db/backups/study_time_YYYY-MM-DD_HHMMSS.sql"; \
		exit 1; \
	fi
	@if [ ! -f "$(FILE)" ]; then \
		echo "File not found: $(FILE)"; \
		exit 1; \
	fi
	@echo "Restoring $(FILE) ..."
	@docker compose exec -T postgres psql -U study -d study_time < "$(FILE)"
	@echo "Restore complete."

db-wait:
	@echo "Waiting for Postgres..."
	@until docker compose exec -T postgres pg_isready -U study -d study_time >/dev/null 2>&1; do \
		sleep 1; \
	done
	@echo "Postgres is ready"

install:
	@test -d .venv || python3 -m venv .venv
	$(PIP) install -r backend/requirements.txt
	npm install

migrate:
	$(DJANGO) migrate

backend:
	$(DJANGO) runserver 0.0.0.0:8000

frontend:
	npm run dev -- --hostname 0.0.0.0

dev: backend

build:
	npm run build

# Explicit destructive target only. Refuses without CONFIRM=YES.
db-wipe:
	@if [ "$(CONFIRM)" != "YES" ]; then \
		echo "Refusing to wipe database."; \
		echo "This deletes the Postgres volume permanently."; \
		echo "If you really mean it: make db-wipe CONFIRM=YES"; \
		exit 1; \
	fi
	@echo "Wiping Postgres volume..."
	docker compose down -v
	@echo "Volume removed. Run make setup to recreate an empty database."
