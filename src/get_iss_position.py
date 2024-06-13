import requests
import json
import datetime
import boto3
import pandas as pd
from io import StringIO

req = requests.get("http://api.open-notify.org/iss-now.json")
resp = json.loads(req.content)

longitude = float(resp['iss_position']['longitude'])
latitude = float(resp['iss_position']['latitude'])
timestamp = datetime.datetime.fromtimestamp(int(resp['timestamp']))

iss_df = pd.DataFrame.from_dict(
    {'longitude': [longitude],
     'latitude': [latitude],
     'timestamp_est': [timestamp]}
)

# write to new folder for current date in S3 bucket
s3_client = boto3.client('s3')
bucket = 'iss-location'
datestamp = timestamp.strftime('%Y-%m-%d')

with StringIO() as csv_buffer:
    iss_df.to_csv(csv_buffer, index=False)

    response = s3_client.put_object(
        Bucket=bucket,
        Key=f"{datestamp}/iss_location.csv",
        Body=csv_buffer.getvalue()
    )

    status = response.get('ResponseMetadata', {}).get('HTTPStatusCode')
    
    if status == 200:
        print(f"Successful S3 put_object response. Status - {status}")
    else:
        print(f"Unsuccessful S3 put_object response. Status - {status}")