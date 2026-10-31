{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://nhtsa-safety-lakehouse-gold-dev/parquet-data/',
    s3_data_naming='table'
) }}

WITH complaints_dim AS (
    SELECT DISTINCT
        UPPER(TRIM(Make)) AS Make,
        UPPER(TRIM(Model)) AS Model,
        TRY_CAST(Model_Year AS INTEGER) AS Model_Year,
        UPPER(TRIM(Primary_Component)) AS Component
    FROM {{ ref('silver_nhtsa_complaints') }}
    WHERE Make IS NOT NULL
),

recalls_dim AS (
    SELECT DISTINCT
        UPPER(TRIM(Make)) AS Make,
        UPPER(TRIM(Model)) AS Model,
        TRY_CAST(ModelYear AS INTEGER) AS Model_Year,
        UPPER(TRIM(Component)) AS Component
    FROM {{ ref('silver_nhtsa_recalls') }}
    WHERE Make IS NOT NULL
)

SELECT * FROM complaints_dim
UNION
SELECT * FROM recalls_dim