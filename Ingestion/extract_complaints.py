import requests
import boto3
import zipfile
import io
from datetime import datetime

def fetch_bulk_complaints():
    bucket_name = "nhtsa-safety-lakehouse-bronze-dev"
    region = "us-east-2"
    s3 = boto3.client('s3', region_name=region)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # Official NHTSA bulk complaints ZIP endpoint
    zip_url = "https://static.nhtsa.gov/odi/ffdd/cmpl/FLAT_CMPL.zip"
    
    print(f"Downloading complete historical complaints ZIP from {zip_url}...")
    
    try:
        # 1. Download the bulk ZIP file
        response = requests.get(zip_url, timeout=300)
        response.raise_for_status()
        print("Download complete. Extracting file in memory...")
        
        # 2. Extract the ZIP in memory using io.BytesIO
        with zipfile.ZipFile(io.BytesIO(response.content)) as z:
            # The ZIP contains a single flat text file
            for file_info in z.infolist():
                if file_info.filename.endswith('.txt'):
                    print(f"Found flat file: {file_info.filename}. Uploading to S3 Bronze...")
                    
                    # Read the extracted data
                    extracted_data = z.read(file_info.filename)
                    
                    # 3. Stream directly into the new raw_complaints prefix
                    file_key = "raw_complaints/FLAT_CMPL_latest.txt"
                    
                    s3.put_object(
                        Bucket=bucket_name,
                        Key=file_key,
                        Body=extracted_data,
                        ContentType='text/plain'
                    )
                    
                    # Calculate size in MB for logging
                    size_mb = len(extracted_data) / (1024 * 1024)
                    print(f"Success! Uploaded {size_mb:.2f} MB to s3://{bucket_name}/{file_key}")
                    break
                    
    except Exception as e:
        print(f"Error processing NHTSA complaints dataset: {e}")

if __name__ == "__main__":
    fetch_bulk_complaints()