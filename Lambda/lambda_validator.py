import json
import os
import boto3
import urllib.parse

s3 = boto3.client('s3')
DLQ_BUCKET = os.environ.get('DLQ_BUCKET')

def quarantine_file(source_bucket, key, reason):
    """Moves invalid object from Bronze to DLQ bucket."""
    print(f"⚠️ Quarantining {key} -> {DLQ_BUCKET} | Reason: {reason}")
    copy_source = {'Bucket': source_bucket, 'Key': key}
    
    # 1. Copy bad file to DLQ
    s3.copy_object(
        CopySource=copy_source,
        Bucket=DLQ_BUCKET,
        Key=f"quarantined/{key}",
        Metadata={'quarantine-reason': reason},
        MetadataDirective='REPLACE'
    )
    # 2. Delete original bad file from Bronze
    s3.delete_object(Bucket=source_bucket, Key=key)
    print(f"Successfully moved {key} to DLQ bucket.")

def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        raw_content = response['Body'].read().decode('utf-8')
    except Exception as e:
        print(f"Failed to read {key} from S3: {str(e)}")
        raise e

    # 1. Check for valid JSON parsing
    try:
        json_data = json.loads(raw_content)
    except Exception as e:
        quarantine_file(bucket, key, f"Malformed JSON: {str(e)}")
        return {'statusCode': 400, 'body': 'Malformed JSON quarantined.'}

    # 2. Check schema contracts (Count & Results)
    if not isinstance(json_data, dict) or 'Count' not in json_data or 'Results' not in json_data:
        quarantine_file(bucket, key, "Missing 'Count' or 'Results' schema keys.")
        return {'statusCode': 400, 'body': 'Invalid schema quarantined.'}

    record_count = json_data.get('Count', 0)
    print(f"Validation Passed: {key} verified ({record_count} records).")
    
    return {
        'statusCode': 200,
        'body': json.dumps('File validated successfully.')
    }