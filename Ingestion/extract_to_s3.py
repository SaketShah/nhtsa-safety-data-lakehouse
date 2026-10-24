import json
import requests
import boto3
import time
from datetime import datetime

import os

def fetch_historical_recalls():
    # Grab the year from Kestra's environment variable
    env_year = os.getenv("INGESTION_YEAR")
    
    # If Kestra sends a year, use only that year. Otherwise, fall back to the historical list.
    if env_year:
        target_years = [int(env_year)]
    else:
        target_years = [2020, 2021, 2022, 2023, 2024]
        
    target_makes = [
        "ford", "tesla", "honda", "toyota", "chevrolet",
        "nissan", "bmw", "audi", "hyundai", "kia"
    ]
    
    bucket_name = "nhtsa-safety-lakehouse-bronze-dev" # Update this
    region = "us-east-2"
    s3 = boto3.client('s3', region_name=region)
    
    total_records_pulled = 0
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    print("Starting dynamic 2020-2024 Historical Backfill for all models...")
    
    for year in target_years:
        for make in target_makes:
            # 1. Fetch all models for this specific make and year from the vPIC API
            models_url = f"https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/{make}/modelyear/{year}?format=json"
            
            try:
                models_response = requests.get(models_url, timeout=30)
                if models_response.status_code == 200:
                    models_data = models_response.json()
                    
                    # Extract the model names into a list
                    models = [item.get('Model_Name') for item in models_data.get('Results', []) if item.get('Model_Name')]
                    print(f"\nFound {len(models)} models for {make.title()} in {year}.")
                    
                    # 2. Loop through every model found and fetch its recalls
                    for model in models:
                        recall_url = f"https://api.nhtsa.gov/recalls/recallsByVehicle?make={make}&model={model}&modelYear={year}"
                        
                        recall_response = requests.get(recall_url, timeout=30)
                        if recall_response.status_code == 200:
                            data = recall_response.json()
                            results = data.get("results", [])
                            
                            if results:
                                # Clean up the filename by removing spaces and slashes
                                clean_model = str(model).replace(' ', '').replace('/', '-')
                                file_name = f"recalls_{make}_{clean_model}_{year}_{timestamp}.json"
                                
                                s3.put_object(
                                    Bucket=bucket_name,
                                    Key=f"raw/historical/{file_name}",
                                    Body=json.dumps(data),
                                    ContentType='application/json'
                                )
                                record_count = data.get("count", len(results))
                                total_records_pulled += record_count
                                print(f"Uploaded {year} {make.title()} {model.title()}: {record_count} records")
                        
                        # Polite API pacing to avoid timeouts
                        time.sleep(1)
                        
            except Exception as e:
                print(f"Error processing {year} {make}: {e}")

    print(f"\nBackfill Complete! Total records ingested into Bronze: {total_records_pulled}")

if __name__ == "__main__":
    fetch_historical_recalls()