# Database backup & restore

Move topics and study sessions to another machine.

**Important:** dump files are **not** in git (`.gitignore`). You must copy the file yourself (USB, `scp`, etc.).

## Backup (source machine)

```bash
make stop          # optional, avoids mid-timer writes
make db-backup
```

Creates two files in `db/backups/`:

| File | Use |
| ---- | --- |
| `study_time_TIME.data.sql` | **Use this** — data only, portable |
| `study_time_TIME.full.sql` | Full schema+data (fallback) |

Example:

```text
db/backups/study_time_2026-07-25_142500.data.sql
```

Backup prints topic/session counts. If topics are `0`, you backed up an empty DB.

Copy the `.data.sql` file to the new server’s `db/backups/` folder.

## Restore (new server)

```bash
# 1. App + empty database (migrations create tables)
make setup

# 2. Load your dump (use the .data.sql file)
make db-restore FILE=db/backups/study_time_2026-07-25_142500.data.sql

# 3. Confirm counts look right (printed by restore)
# 4. Run the app
make up
```

Restore **clears** `topics` / `study_sessions` then inserts from the dump. It stops on SQL errors instead of failing quietly.

## Verify anytime

```bash
make db-verify
```

## Manual commands

```bash
# backup (data only)
docker compose exec -T postgres pg_dump -U study -d study_time \
  --data-only --column-inserts --no-owner --no-acl \
  | sed '/^\\restrict/d;/^\\unrestrict/d' \
  > db/backups/manual.data.sql

# restore
docker compose exec -T postgres \
  psql -U study -d study_time -v ON_ERROR_STOP=1 \
  -c "TRUNCATE TABLE study_sessions, topics RESTART IDENTITY CASCADE;"
docker compose exec -T postgres \
  psql -U study -d study_time -v ON_ERROR_STOP=1 < db/backups/manual.data.sql
```

## Checklist if the other server looks empty

1. Did you copy the `.data.sql` file? (git clone alone will not include it)
2. Run `make db-verify` on the new server — topics should be &gt; 0
3. Confirm `.env` has `DATABASE_URL=postgresql://study:study@localhost:5432/study_time`
4. Restart app: `make stop && make up`
5. Open `http://localhost:3000` (not an old Network URL from another machine)

## Defaults

| Field | Value |
| ----- | ----- |
| User | `study` |
| Password | `study` |
| Database | `study_time` |
| Port | `5432` |
