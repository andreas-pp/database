# Services Database

3 instance Postgres terpisah, satu per service: **Airflow** (metadata), **Superset** (metadata), **Airflow Config** (table config ingestion `airflow_config.*`).

## Isi

| Path | Fungsi |
|---|---|
| `docker-compose.yml` | 3 container: `postgres-airflow` / `postgres-superset` / `postgres-config`, network `services-db` (shared ke stack lain) |
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

## Consume dari stack lain

Network `services-db` external. Di compose stack consumer:

```yaml
networks:
  services-db:
    external: true

services:
  app:
    networks: [default, services-db]
    environment:
      DATABASE_HOST: postgres-airflow
```

Koneksi (user = nama DB, satu-satu per container):

- `postgresql://airflow:<AIRFLOW_DB_PASSWORD>@postgres-airflow:5432/airflow`
- `postgresql://superset:<SUPERSET_DB_PASSWORD>@postgres-superset:5432/superset`
- `postgresql://airflow_config:<CONFIG_DB_PASSWORD>@postgres-config:5432/airflow_config`

## Catatan

- `docker compose` (plugin v2) rusak di beberapa shell — pakai `docker-compose`.
- Superuser tiap container = user service (airflow/superset/airflow_config), DB dibuat otomatis oleh image — tidak perlu init script.
- Reset satu service = hapus `./pg-*-data` miliknya + `docker-compose up -d` lagi (data service itu hilang).
- Self-signed TLS / port eksternal tidak dibuka — konsumsi lewat network docker internal.
