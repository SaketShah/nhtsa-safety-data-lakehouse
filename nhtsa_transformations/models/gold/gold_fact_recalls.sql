{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://nhtsa-safety-lakehouse-gold-dev/parquet-data/',
    s3_data_naming='table'
) }}

SELECT
    UPPER(TRIM(Make)) AS Make,
    UPPER(TRIM(Model)) AS Model,
    TRY_CAST(ModelYear AS INTEGER) AS Model_Year,
    UPPER(TRIM(Component)) AS Component,
    
    COUNT(DISTINCT NHTSACampaignNumber) AS Total_Recalls

FROM {{ ref('silver_nhtsa_recalls') }}
GROUP BY 1, 2, 3, 4