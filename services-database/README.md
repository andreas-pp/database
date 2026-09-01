# Services Database

Satu instance Postgres untuk 3 service: **Airflow** (metadata), **Superset** (metadata), **Airflow Config** (table config ingestion `airflow_config.*`).

## Isi

| Path | Fungsi |
|---|---|
| `docker-compose.yml` | postgres:18 → container `services-postgres`, network `services-db` (shared ke stack lain) |
| `init/10-create-roles.sh` | auto-create role + database `airflow` / `superset` / `airflow_config` (sekali, saat data dir kosong) |
| `config/airflow_config_init.sql` | DDL + seed schema `airflow_config` — jalankan manual setelah stack naik |

## Deploy di server

```bash
git clone https://github.com/andreas-pp/database.git database
cd database/services-database

# 1. env: cp .env.example .env lalu isi
# 2. naikkan
docker-compose up -d

# 3. schema config ingestion (sekali)
docker exec -i services-postgres psql -U postgres -d airflow_config -a -f - < config/airflow_config_init.sql
```

State di bind mount lokal: `./postgres-data`.

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
      DATABASE_HOST: services-postgres
```

Koneksi: `postgresql://airflow:<AIRFLOW_DB_PASSWORD>@services-postgres:5432/airflow` (idem `superset`@5432/superset, `airflow_config`@5432/airflow_config).

## Catatan

- `docker compose` (plugin v2) rusak di beberapa shell — pakai `docker-compose`.
- Password role ter-cetak saat init pertama saja. Reset = hapus `./postgres-data` + up lagi (data hilang) atau `ALTER ROLE` manual.
- Self-signed TLS / port eksternal tidak dibuka — konsumsi lewat network docker internal.
