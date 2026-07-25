# Database backup & restore

Use this when moving Study Tracker to another machine. Copy the dump file with the repo (or store it safely), then restore after Postgres is up.

## Backup (this machine)

Postgres must be running (`make db-up` or `make up`).

```bash
make db-backup
```

Creates a timestamped file under `db/backups/`, for example:

```text
db/backups/study_time_2026-07-25_140401.sql
```

Or manually:

```bash
mkdir -p db/backups
docker compose exec -T postgres pg_dump -U study -d study_time --clean --if-exists \
  > "db/backups/study_time_$(date +%Y-%m-%d_%H%M%S).sql"
```

Copy that `.sql` file to the new server (USB, scp, cloud, etc.).

## Restore (new server)

1. Clone/copy the project and start Postgres (empty DB is fine):

```bash
make setup
```

2. Put the dump in `db/backups/` (or any path).

3. Restore:

```bash
make db-restore FILE=db/backups/study_time_2026-07-25_140401.sql
```

Or manually:

```bash
docker compose exec -T postgres psql -U study -d study_time < db/backups/your_dump.sql
```

4. Start the app:

```bash
make up
```

## Notes

| Item | Detail |
| ---- | ------ |
| What is backed up | All tables (`topics`, `study_sessions`, Django migrations, etc.) |
| Password | User `study` / password `study` (local Docker defaults) |
| Safe with running app | Prefer `make stop` first so no open timer is mid-write |
| Does not wipe volume | Restore overwrites table data via SQL; it does not run `db-wipe` |

`db/backups/*.sql` is gitignored — treat dumps as private data and copy them yourself.
