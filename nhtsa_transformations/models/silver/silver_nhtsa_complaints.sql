{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://nhtsa-safety-lakehouse-silver-dev/parquet-data/',
    s3_data_naming='table'
) }}

WITH raw_complaints AS (
    SELECT * FROM bronze_raw_complaints
)

SELECT
    cmplid AS Complaint_ID,
    odino AS ODI_Number,
    UPPER(TRIM(maketxt)) AS Make,
    
    -- Athena regex to replicate INITCAP for Model
    regexp_replace(TRIM(modeltxt), '(\w)(\w*)', x -> upper(x[1]) || lower(x[2])) AS Model,
    
    try_cast(yeartxt AS INTEGER) AS Model_Year,
    
    -- Replicate standard brand mapping used in Recalls
    CASE 
        WHEN LOWER(mfr_name) LIKE '%toyota%' THEN 'TOYOTA'
        WHEN LOWER(mfr_name) LIKE '%kia%' THEN 'KIA'
        WHEN LOWER(mfr_name) LIKE '%honda%' THEN 'HONDA'
        WHEN LOWER(mfr_name) LIKE '%general motors%' THEN 'GENERAL MOTORS'
        WHEN LOWER(mfr_name) LIKE '%isuzu%' THEN 'ISUZU'
        WHEN LOWER(mfr_name) LIKE '%bmw%' THEN 'BMW'
        WHEN LOWER(mfr_name) LIKE '%hyundai%' THEN 'HYUNDAI'
        WHEN LOWER(mfr_name) LIKE '%subaru%' THEN 'SUBARU'
        WHEN LOWER(mfr_name) LIKE '%ford%' THEN 'FORD'
        WHEN LOWER(mfr_name) LIKE '%volkswagen%' THEN 'VOLKSWAGEN'
        WHEN LOWER(mfr_name) LIKE '%nissan%' THEN 'NISSAN'
        WHEN LOWER(mfr_name) LIKE '%tesla%' THEN 'TESLA'
        ELSE UPPER(TRIM(REGEXP_REPLACE(mfr_name, '(?i)\s*(LLC|Inc\.|Corp\.|Corporation|Company|Motor|Group of America)\s*', ''))) 
    END AS Manufacturer_Clean,
    
    mfr_name AS Manufacturer_Original,
    
    -- Isolate primary component exactly like Recalls
    UPPER(TRIM(SPLIT_PART(compdesc, ':', 1))) AS Primary_Component,
    compdesc AS Component_Original,
    cdescr AS Summary,
    
    -- Convert string flags to binary for Power BI
    CASE WHEN upper(crash) = 'Y' THEN 1 ELSE 0 END AS Flag_Crash,
    CASE WHEN upper(fire) = 'Y' THEN 1 ELSE 0 END AS Flag_Fire,
    
    TRY_CAST(injured AS INTEGER) AS Number_Injured,
    TRY_CAST(deaths AS INTEGER) AS Number_Deaths

FROM raw_complaints
-- Locks the dataset exactly to your required analytical window
WHERE try_cast(yeartxt AS INTEGER) BETWEEN 2020 AND 2026