{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://nhtsa-safety-lakehouse-gold-dev/parquet-data/',
    s3_data_naming='table'
) }}

WITH recalls_summary AS (
    SELECT 
        Manufacturer_Clean,
        Make,
        Model,
        TRY_CAST(Model_Year AS INTEGER) AS Model_Year,
        Primary_Component,
        COUNT(DISTINCT Campaign_Number) AS Total_Recalls,
        MAX(Risk_Crash) AS Had_Crash_Recall,
        MAX(Risk_Fire) AS Had_Fire_Recall
    FROM {{ ref('gold_recall_fact') }}
    WHERE Model_Year IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),

complaints_summary AS (
    SELECT
        Manufacturer_Clean,
        Make,
        Model,
        TRY_CAST(Model_Year AS INTEGER) AS Model_Year,
        Primary_Component,
        COUNT(DISTINCT Complaint_ID) AS Total_Complaints,
        SUM(COALESCE(Number_Injured, 0)) AS Total_Injuries,
        SUM(COALESCE(Number_Deaths, 0)) AS Total_Deaths,
        MAX(Flag_Crash) AS Had_Crash_Complaint,
        MAX(Flag_Fire) AS Had_Fire_Complaint
    FROM {{ ref('silver_nhtsa_complaints') }}
    WHERE Model_Year IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    COALESCE(c.Manufacturer_Clean, r.Manufacturer_Clean) AS Manufacturer,
    COALESCE(c.Make, r.Make) AS Make,
    COALESCE(c.Model, r.Model) AS Model,
    COALESCE(c.Model_Year, r.Model_Year) AS Model_Year,
    COALESCE(c.Primary_Component, r.Primary_Component) AS Primary_Component,
    
    COALESCE(c.Total_Complaints, 0) AS Total_Complaints,
    COALESCE(r.Total_Recalls, 0) AS Total_Recalls,
    COALESCE(c.Total_Injuries, 0) AS Total_Injuries,
    COALESCE(c.Total_Deaths, 0) AS Total_Deaths,
    
    -- Analytical KPI: Complaints per Recall
    CASE 
        WHEN COALESCE(r.Total_Recalls, 0) = 0 THEN CAST(COALESCE(c.Total_Complaints, 0) AS DOUBLE)
        ELSE ROUND(CAST(COALESCE(c.Total_Complaints, 0) AS DOUBLE) / r.Total_Recalls, 2)
    END AS Complaints_Per_Recall,
    
    -- Discrepancy KPI: Flagging high-complaint vehicles with no recall issued
    CASE 
        WHEN COALESCE(r.Total_Recalls, 0) = 0 AND COALESCE(c.Total_Complaints, 0) >= 10 THEN 1 
        ELSE 0 
    END AS High_Unaddressed_Risk_Flag,

    COALESCE(r.Had_Crash_Recall, 0) AS Had_Crash_Recall,
    COALESCE(r.Had_Fire_Recall, 0) AS Had_Fire_Recall,
    COALESCE(c.Had_Crash_Complaint, 0) AS Had_Crash_Complaint,
    COALESCE(c.Had_Fire_Complaint, 0) AS Had_Fire_Complaint

FROM complaints_summary c
FULL OUTER JOIN recalls_summary r
    ON c.Make = r.Make
    AND c.Model = r.Model
    AND c.Model_Year = r.Model_Year
    AND c.Primary_Component = r.Primary_Component