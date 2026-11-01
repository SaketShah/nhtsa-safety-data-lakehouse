{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://nhtsa-safety-lakehouse-gold-dev/parquet-data/',
    s3_data_naming='table'
) }}

WITH cleaned_complaints AS (
    SELECT
        UPPER(TRIM(Make)) AS Make,
        UPPER(TRIM(Model)) AS Model,
        TRY_CAST(Model_Year AS INTEGER) AS Model_Year,
        UPPER(TRIM(Primary_Component)) AS Component,
        Flag_Crash,
        Flag_Fire,
        Number_Injured,
        Number_Deaths
    FROM {{ ref('silver_nhtsa_complaints') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['Make', 'Model', 'Model_Year']) }} AS vehicle_id,
    Make,
    Model,
    Model_Year,
    Component,
    
    COUNT(*) AS Total_Complaints,
    SUM(Flag_Crash) AS Total_Crashes,
    SUM(Flag_Fire) AS Total_Fires,
    SUM(Number_Injured) AS Total_Injuries,
    SUM(Number_Deaths) AS Total_Deaths

FROM cleaned_complaints
GROUP BY 1, 2, 3, 4, 5