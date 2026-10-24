{{ config(
    materialized='table',
    format='parquet',
    write_compression='snappy'
) }}

WITH unnested_data AS (
    SELECT 
        recall.NHTSACampaignNumber,
        recall.Manufacturer,
        recall.Make,
        recall.Model,
        recall.ModelYear,
        recall.Component,
        recall.Summary,
        recall.Consequence,
        recall.Remedy,
        recall.Notes
    FROM {{ source('bronze_source', 'nhtsa_bronze_raw') }}
    CROSS JOIN UNNEST(Results) AS t(recall)
    WHERE recall.NHTSACampaignNumber IS NOT NULL
),

deduplicated_data AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY NHTSACampaignNumber, Make, Model, ModelYear 
            ORDER BY NHTSACampaignNumber
        ) as row_num
    FROM unnested_data
)

SELECT 
    NHTSACampaignNumber,
    Manufacturer,
    Make,
    Model,
    ModelYear,
    Component,
    Summary,
    Consequence,
    Remedy,
    Notes
FROM deduplicated_data
WHERE row_num = 1