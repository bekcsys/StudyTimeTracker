# Database backup & restore

One backup file. Copy it to the other server. Restore it there.

Dumps are **not** in git — you must copy the `.sql` file yourself.

## Backup

```bash
make db-backup
```

Writes:

```text
db/backups/study_time_YYYY-MM-DD_HHMMSS.sql
db/backups/latest.sql                  (same content, easy name)
```

Only `topics` and `study_sessions` are exported (what the app shows).

## Restore on another server

1. Copy `latest.sql` (or the timestamped file) into that machine’s `db/backups/`
2. Run:

```bash
make setup
make db-restore FILE=db/backups/latest.sql
make up
```

## Check data

```bash
make db-verify
```

You should see topic names and session counts &gt; 0.

## If the other server is still empty

1. Confirm the `.sql` file exists on that machine (`ls db/backups/`)
2. Open it — you should see `INSERT INTO public.topics`
3. Run `make db-verify` after restore
4. Use `http://localhost:3000` on that machine
