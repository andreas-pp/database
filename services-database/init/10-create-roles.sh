#!/bin/bash
# Dibaca docker-entrypoint sekali (saat postgres-data kosong).
# Buat role + database per service: airflow, superset, airflow_config.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<EOSQL
CREATE ROLE airflow LOGIN PASSWORD '${AIRFLOW_DB_PASSWORD}';
CREATE DATABASE airflow OWNER airflow;

CREATE ROLE superset LOGIN PASSWORD '${SUPERSET_DB_PASSWORD}';
CREATE DATABASE superset OWNER superset;

CREATE ROLE airflow_config LOGIN PASSWORD '${CONFIG_DB_PASSWORD}';
CREATE DATABASE airflow_config OWNER airflow_config;
EOSQL

echo "roles + databases created: airflow, superset, airflow_config"
