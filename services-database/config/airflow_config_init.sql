-- airflow_config: table config utk unified multi-engine ingestion (PG/DB2/MySQL -> ClickHouse)
-- Database: airflow_config (instance sama dgn metadata Airflow, container bntbs-data-platform-postgres-1)
-- Schema  : airflow_config
-- Dijalankan sekali saat init; perubahan seed manual.

CREATE SCHEMA IF NOT EXISTS airflow_config;

-- ---------- lookup ----------
CREATE TABLE IF NOT EXISTS airflow_config.ref_ingest_mode (
    id   smallint PRIMARY KEY,
    name text NOT NULL UNIQUE
);
INSERT INTO airflow_config.ref_ingest_mode (id, name) VALUES
    (1, 'full'), (2, 'incremental'), (3, 'snapshot')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS airflow_config.ref_pipeline (
    id           smallint PRIMARY KEY,
    name         text NOT NULL UNIQUE,
    cron_default text
);
INSERT INTO airflow_config.ref_pipeline (id, name, cron_default) VALUES
    (1, 'hourly', '0 * * * *'),
    (2, 'daily', '0 2 * * *'),
    (99, 'forced_backfill', NULL)
ON CONFLICT (id) DO UPDATE SET cron_default = EXCLUDED.cron_default;

-- ---------- config ----------
CREATE TABLE IF NOT EXISTS airflow_config.ingestion_sources (
    id          serial PRIMARY KEY,
    source_name text NOT NULL UNIQUE,
    engine      text NOT NULL CHECK (engine IN ('pg', 'db2', 'mysql')),
    conn_id     text NOT NULL,
    ch_conn_id  text NOT NULL DEFAULT 'clickhouse__warehouse',
    ch_db       text NOT NULL,
    cluster     text NOT NULL DEFAULT 'clickhouse_cluster',
    schedule    text,
    enabled     boolean NOT NULL DEFAULT true,
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS airflow_config.ingestion_tables (
    id                serial PRIMARY KEY,
    source_id         int NOT NULL REFERENCES airflow_config.ingestion_sources(id) ON DELETE CASCADE,
    schema_name       text,
    table_name        text NOT NULL,
    mode_id           smallint NOT NULL REFERENCES airflow_config.ref_ingest_mode(id),
    pk                text[] NOT NULL DEFAULT '{}',
    updated_col       text,
    updated_col_tz    text NOT NULL DEFAULT 'UTC',
    created_col       text,
    backfill_eligible boolean NOT NULL DEFAULT false,
    enabled           boolean NOT NULL DEFAULT true,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (source_id, schema_name, table_name)
);

CREATE TABLE IF NOT EXISTS airflow_config.ingestion_table_pipeline (
    table_id    int NOT NULL REFERENCES airflow_config.ingestion_tables(id) ON DELETE CASCADE,
    pipeline_id smallint NOT NULL REFERENCES airflow_config.ref_pipeline(id),
    PRIMARY KEY (table_id, pipeline_id)
);

-- constraint bisnis: incremental WAJIB punya pk
ALTER TABLE airflow_config.ingestion_tables
    ADD CONSTRAINT chk_incremental_needs_pk
    CHECK (mode_id <> 2 OR (pk <> '{}' AND updated_col IS NOT NULL));

-- idempotent utk DB yang sudah jalan sebelum kolom schedule ada
ALTER TABLE airflow_config.ingestion_sources ADD COLUMN IF NOT EXISTS schedule text;
ALTER TABLE airflow_config.ingestion_tables ADD COLUMN IF NOT EXISTS updated_col_tz text NOT NULL DEFAULT 'UTC';

-- ---------- seed: db2_sample (Fase 4) ----------
-- Conn Airflow `db2__sample`: host=host.docker.internal port=50000 schema=SAMPLE login=db2inst1
INSERT INTO airflow_config.ingestion_sources (source_name, engine, conn_id, ch_db, schedule)
VALUES ('db2_sample', 'db2', 'db2__sample', 'staging_db2', '0 4 * * *')
ON CONFLICT (source_name) DO NOTHING;

WITH s AS (SELECT id FROM airflow_config.ingestion_sources WHERE source_name = 'db2_sample')
INSERT INTO airflow_config.ingestion_tables (source_id, schema_name, table_name, mode_id, pk)
SELECT s.id, 'DB2INST1', 'EMPLOYEE', 1, ARRAY['EMPNO'] FROM s
ON CONFLICT (source_id, schema_name, table_name) DO NOTHING;

WITH t AS (
    SELECT it.id
    FROM airflow_config.ingestion_tables it
    JOIN airflow_config.ingestion_sources s ON s.id = it.source_id
    WHERE s.source_name = 'db2_sample' AND it.table_name = 'EMPLOYEE'
)
INSERT INTO airflow_config.ingestion_table_pipeline (table_id, pipeline_id)
SELECT t.id, 2 FROM t
ON CONFLICT DO NOTHING;
