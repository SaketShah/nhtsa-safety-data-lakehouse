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
        TRY_CAST(Model_Year AS INTEGER) AS Model_Year
    FROM {{ ref('silver_nhtsa_complaints') }}
    WHERE Make IS NOT NULL
),

recalls_dim AS (
    SELECT DISTINCT
        UPPER(TRIM(Make)) AS Make,
        UPPER(TRIM(Model)) AS Model,
        TRY_CAST(ModelYear AS INTEGER) AS Model_Year
    FROM {{ ref('silver_nhtsa_recalls') }}
    WHERE Make IS NOT NULL
),

combined_vehicles AS (
    SELECT * FROM complaints_dim
    UNION
    SELECT * FROM recalls_dim
)

SELECT 
    {{ dbt_utils.generate_surrogate_key(['Make', 'Model', 'Model_Year']) }} AS vehicle_id,
    Make,
    Model,
    Model_Year
FROM combined_vehicles