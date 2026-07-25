.PHONY: help setup env db-up db-down db-wait install migrate up down \
	backend frontend dev build reset

PYTHON := .venv/bin/python
PIP := .venv/bin/pip
DJANGO := $(PYTHON) backend/manage.py

help:
	@echo "Study Tracker"
	@echo ""
	@echo "  make up        Start Postgres, install, migrate, run Django + Next"
	@echo "  make down      Stop Postgres"
	@echo "  make setup     Env + Postgres + install + migrate (no servers)"
	@echo "  make backend   Run Django API on :8000"
	@echo "  make frontend  Run Next.js on :3000"
	@echo "  make migrate   Apply Django migrations"
	@echo "  make reset     Wipe local DB volume and set up again"

setup: env db-up db-wait install migrate
	@echo "Ready. Run: make up"

up: setup
	$(MAKE) -j2 backend frontend

down: db-down

env:
	@test -f .env || cp .env.example .env
	@echo ".env ready"

db-up:
	docker compose up -d

db-down:
	docker compose down

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
	$(DJANGO) runserver 8000

frontend:
	npm run dev

dev: backend

build:
	npm run build

reset:
	docker compose down -v
	$(MAKE) setup
