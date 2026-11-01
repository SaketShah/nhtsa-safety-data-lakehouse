{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://nhtsa-safety-lakehouse-gold-dev/parquet-data/',
    s3_data_naming='table'
) }}

WITH cleaned_recalls AS (
    SELECT
        UPPER(TRIM(Make)) AS Make,
        UPPER(TRIM(Model)) AS Model,
        TRY_CAST(ModelYear AS INTEGER) AS Model_Year,
        UPPER(TRIM(Component)) AS Component,
        NHTSACampaignNumber
    FROM {{ ref('silver_nhtsa_recalls') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['Make', 'Model', 'Model_Year']) }} AS vehicle_id,
    Make,
    Model,
    Model_Year,
    Component,
    
    COUNT(DISTINCT NHTSACampaignNumber) AS Total_Recalls

FROM cleaned_recalls
GROUP BY 1, 2, 3, 4, 5