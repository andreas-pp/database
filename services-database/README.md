# Services Database

3 instance Postgres terpisah, satu per service: **Airflow** (metadata), **Superset** (metadata), **Airflow Config** (table config ingestion `airflow_config.*`). Port di-export ke host, tidak pakai network internal.

| Container | Host port | DB / user |
|---|---|---|
| `postgres-airflow` | 5432 | airflow |
| `postgres-superset` | 5433 | superset |
| `postgres-config` | 5434 | airflow_config |

## Isi

| Path | Fungsi |
|---|---|
| `docker-compose.yml` | 3 container postgres:18, port exported |
| `config/airflow_config_init.sql` | DDL + seed schema `airflow_config` — jalankan manual setelah stack naik |

## Deploy di server

```bash
git clone https://github.com/andreas-pp/database.git database
cd database/services-database

# 1. env: cp .env.example .env lalu isi
# 2. naikkan
docker-compose up -d

# 3. schema config ingestion (sekali)
docker exec -i postgres-config psql -U airflow_config -d airflow_config -a -f - < config/airflow_config_init.sql
```

State di bind mount lokal: `./pg-airflow-data`, `./pg-superset-data`, `./pg-config-data`.

## Koneksi (dari host)

- `postgresql://airflow:<AIRFLOW_DB_PASSWORD>@localhost:5432/airflow`
- `postgresql://superset:<SUPERSET_DB_PASSWORD>@localhost:5433/superset`
- `postgresql://airflow_config:<CONFIG_DB_PASSWORD>@localhost:5434/airflow_config`

Dari container stack lain: ganti `localhost` dengan host IP / `host.docker.internal`.

## Catatan

- `docker compose` (plugin v2) rusak di beberapa shell — pakai `docker-compose`.
- Superuser tiap container = user service (airflow/superset/airflow_config), DB dibuat otomatis oleh image — tidak perlu init script.
- Reset satu service = hapus `./pg-*-data` miliknya + `docker-compose up -d` lagi (data service itu hilang).
- Port ter-export langsung — pastikan firewall membatasi akses, password adalah satu-satunya proteksi.
