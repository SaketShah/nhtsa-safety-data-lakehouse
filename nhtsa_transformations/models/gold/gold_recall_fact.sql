{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://nhtsa-safety-lakehouse-gold-dev/parquet-data/',
    s3_data_naming='table'
) }}

WITH base_silver AS (
    SELECT
        nhtsacampaignnumber AS Campaign_Number,
        UPPER(TRIM(make)) AS Make,
        regexp_replace(TRIM(model), '(\w)(\w*)', x -> upper(x[1]) || lower(x[2])) AS Model,
        modelyear AS Model_Year,
        manufacturer AS Manufacturer_Original,
        component AS Component_Original,
        
        -- Isolates the 34 distinct primary components by splitting at the colon
        UPPER(TRIM(SPLIT_PART(component, ':', 1))) AS Primary_Component,
        
        summary AS Summary,
        consequence AS Consequence,
        remedy AS Remedy,
        notes AS Notes
    FROM {{ ref('silver_nhtsa_recalls') }}
),

mapped_brands AS (
    SELECT
        *,
        -- Standardized Parent Brand Mapping
        CASE 
            WHEN LOWER(Manufacturer_Original) LIKE '%toyota%' THEN 'TOYOTA'
            WHEN LOWER(Manufacturer_Original) LIKE '%kia%' THEN 'KIA'
            WHEN LOWER(Manufacturer_Original) LIKE '%honda%' THEN 'HONDA'
            WHEN LOWER(Manufacturer_Original) LIKE '%general motors%' THEN 'GENERAL MOTORS'
            WHEN LOWER(Manufacturer_Original) LIKE '%isuzu%' THEN 'ISUZU'
            WHEN LOWER(Manufacturer_Original) LIKE '%bmw%' THEN 'BMW'
            WHEN LOWER(Manufacturer_Original) LIKE '%hyundai%' THEN 'HYUNDAI'
            WHEN LOWER(Manufacturer_Original) LIKE '%subaru%' THEN 'SUBARU'
            WHEN LOWER(Manufacturer_Original) LIKE '%ford%' THEN 'FORD'
            WHEN LOWER(Manufacturer_Original) LIKE '%volkswagen%' THEN 'VOLKSWAGEN'
            WHEN LOWER(Manufacturer_Original) LIKE '%nissan%' THEN 'NISSAN'
            WHEN LOWER(Manufacturer_Original) LIKE '%tesla%' THEN 'TESLA'
            -- Fallback for upfitters and mobility companies
            ELSE UPPER(TRIM(REGEXP_REPLACE(Manufacturer_Original, '(?i)\s*(LLC|Inc\.|Corp\.|Corporation|Company|Motor|Group of America)\s*', ''))) 
        END AS Manufacturer_Clean
    FROM base_silver
),

enriched_flags AS (
    SELECT
        Campaign_Number,
        Manufacturer_Clean,
        Make,
        Model,
        Model_Year,
        Primary_Component,
        
        -- Calculated Risk Flags for BI
        CASE WHEN LOWER(Consequence) LIKE '%crash%' THEN 1 ELSE 0 END AS Risk_Crash,
        CASE WHEN LOWER(Consequence) LIKE '%fire%' THEN 1 ELSE 0 END AS Risk_Fire,
        CASE WHEN LOWER(Consequence) LIKE '%injury%' THEN 1 ELSE 0 END AS Risk_Injury,
        CASE WHEN LOWER(Summary) LIKE '%fmvss%' OR LOWER(Summary) LIKE '%fail to comply%' THEN 1 ELSE 0 END AS Compliance_Issue,
        
        Manufacturer_Original,
        Component_Original,
        Summary,
        Consequence,
        Remedy,
        Notes
    FROM mapped_brands
)

SELECT * FROM enriched_flags