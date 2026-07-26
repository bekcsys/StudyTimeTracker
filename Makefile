.DEFAULT_GOAL := help

.PHONY: help setup env db-up db-down db-wait db-ui db-ui-down db-backup db-restore \
	db-verify ensure-deps install migrate up down stop backend frontend dev build db-wipe

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
	@echo "  make up          Start Postgres + Django + Next"
	@echo "  make stop        Stop Next + Django only (Postgres data untouched)"
	@echo "  make down        Stop Postgres container (keeps data volume)"
	@echo "  make setup       Env + Postgres + install + migrate (no servers)"
	@echo "  make install     Force reinstall Python + npm deps"
	@echo "  make backend     Run Django API on :8000"
	@echo "  make frontend    Run Next.js on :3000"
	@echo "  make migrate     Apply Django migrations"
	@echo "  make db-ui       Start Postgres (if needed) + pgAdmin on :5050"
	@echo "  make db-ui-down  Stop pgAdmin"
	@echo "  make db-backup   Write one SQL dump to db/backups/"
	@echo "  make db-restore  Restore dump (FILE=db/backups/....sql)"
	@echo "  make db-verify   Show topic/session counts"
	@echo "  make db-wipe     DANGER: delete DB volume (requires CONFIRM=YES)"
	@echo ""
	@echo "No make target deletes database data unless you run db-wipe CONFIRM=YES."
	@echo "Backup/restore docs: db/BACKUP.md"
	@echo ""
	@echo "Never run: npm audit fix --force  (it downgrades Next and breaks the app)"

setup: env db-up db-wait install migrate
	@echo "Setup complete. Start with: make up"

# Daily start: skip full reinstall when deps already exist
up: env db-up db-wait ensure-deps migrate
	@echo ""
	@echo "Starting app..."
	@echo "  API  http://127.0.0.1:8000"
	@echo "  App  http://localhost:3000"
	@echo ""
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
	@docker compose up -d

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
	@stamp=$$(date +%Y-%m-%d_%H%M%S); \
	file="$(BACKUP_DIR)/study_time_$$stamp.sql"; \
	docker compose exec -T postgres pg_dump -U study -d study_time \
		--data-only --column-inserts --no-owner --no-acl \
		--table=topics --table=study_sessions \
		| sed '/^\\restrict/d;/^\\unrestrict/d' > "$$file"; \
	cp "$$file" "$(BACKUP_DIR)/latest.sql"; \
	echo "Backup written: $$file"; \
	echo "Also updated:  $(BACKUP_DIR)/latest.sql"; \
	$(MAKE) db-verify; \
	topics=$$(docker compose exec -T postgres psql -U study -d study_time -tAc 'SELECT COUNT(*) FROM topics;'); \
	if [ "$$topics" = "0" ]; then \
		echo "ERROR: database has 0 topics — backup is empty."; \
		exit 1; \
	fi; \
	echo "Copy $$file (or latest.sql) to the other server, then run:"; \
	echo "  make setup && make db-restore FILE=db/backups/latest.sql && make up"

db-restore: db-up db-wait
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make db-restore FILE=db/backups/latest.sql"; \
		exit 1; \
	fi
	@if [ ! -f "$(FILE)" ]; then \
		echo "File not found: $(FILE)"; \
		echo "Backups are not in git. Copy the .sql file into db/backups/ first."; \
		exit 1; \
	fi
	@echo "Restoring $(FILE) ..."
	@docker compose exec -T postgres psql -U study -d study_time -v ON_ERROR_STOP=1 \
		-c "TRUNCATE TABLE study_sessions, topics RESTART IDENTITY CASCADE;"
	@sed '/^\\restrict/d;/^\\unrestrict/d' "$(FILE)" \
		| docker compose exec -T postgres psql -U study -d study_time -v ON_ERROR_STOP=1
	@$(MAKE) db-verify
	@topics=$$(docker compose exec -T postgres psql -U study -d study_time -tAc 'SELECT COUNT(*) FROM topics;'); \
	if [ "$$topics" = "0" ]; then \
		echo "ERROR: restore finished but topics is still empty."; \
		exit 1; \
	fi
	@echo "Restore complete. Start the app with: make up"

db-verify: db-up db-wait
	@echo "Database contents:"
	@docker compose exec -T postgres psql -U study -d study_time -c \
		"SELECT (SELECT COUNT(*) FROM topics) AS topics, (SELECT COUNT(*) FROM study_sessions) AS sessions, (SELECT COALESCE(SUM(accumulated_seconds),0) FROM study_sessions) AS stored_seconds;"
	@docker compose exec -T postgres psql -U study -d study_time -c \
		"SELECT name, color FROM topics ORDER BY name;"

db-wait:
	@echo "Waiting for Postgres..."
	@until docker compose exec -T postgres pg_isready -U study -d study_time >/dev/null 2>&1; do \
		sleep 1; \
	done
	@echo "Postgres is ready"

ensure-deps:
	@if [ ! -x "$(PYTHON)" ] || [ ! -d node_modules ]; then \
		echo "Installing dependencies..."; \
		$(MAKE) install; \
	else \
		echo "Dependencies ready"; \
		npm audit || true; \
	fi

install:
	@test -d .venv || python3 -m venv .venv
	@$(PIP) install -q -r backend/requirements.txt
	@npm install --no-fund

migrate:
	@$(DJANGO) migrate --noinput

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
