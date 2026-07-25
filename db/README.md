# Database access

Local Postgres from root `docker compose`. Query with pgAdmin or any SQL client.

## Quick start (pgAdmin in Docker)

```bash
make db-ui
```

Open [http://localhost:5050](http://localhost:5050)

| Field    | Value               |
| -------- | ------------------- |
| Email    | `admin@example.com` |
| Password | `admin`             |

Server **study_time** is preloaded.

### Postgres password prompt

When pgAdmin asks:

> Please enter the password for the user `study` to connect the server — `study_time`

Use:

```text
study
```

| Prompt                         | Password            |
| ------------------------------ | ------------------- |
| pgAdmin login (web UI)         | `admin`             |
| Postgres user `study` (DB)     | `study`             |

You can check **Save password** so it does not ask again.

Stop:

```bash
make db-ui-down
```

## Connect from desktop pgAdmin / any client

| Field    | Value        |
| -------- | ------------ |
| Host     | `localhost`  |
| Port     | `5432`       |
| Database | `study_time` |
| User     | `study`      |
| Password | `study`      |

URL: `postgresql://study:study@localhost:5432/study_time`

## Schema

See [docs/data-model.md](../docs/data-model.md).

Tables: `topics`, `study_sessions`.

## Data safety

Postgres data lives in the Docker volume `studytime_study_time_pg`.

- `make stop` / `make down` / `make db-ui-down` never delete it
- Only `make db-wipe CONFIRM=YES` removes the volume

To move data to another server, see [BACKUP.md](BACKUP.md).
