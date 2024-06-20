import requests
import json
import datetime
import boto3
import pandas as pd
import pyarrow as pa
from io import BytesIO

def lambda_handler(event, context):
    req = requests.get("http://api.open-notify.org/iss-now.json")
    resp = json.loads(req.content)
    
    longitude = float(resp['iss_position']['longitude'])
    latitude = float(resp['iss_position']['latitude'])
    timestamp = datetime.datetime.fromtimestamp(int(resp['timestamp']))
    
    # convert json response to pandas df
    iss_df = pd.DataFrame.from_dict(
        {'longitude': [longitude],
         'latitude': [latitude],
         'timestamp_utc': [timestamp]}
         )
    
    with BytesIO() as parquet_buffer:
        # convert pandas df for json response to parquet, with schema
        iss_df.to_parquet(
            parquet_buffer,
            schema=pa.schema([('longitude', pa.float64()),
                              ('latitude', pa.float64()),
                              ('timestamp_utc', pa.timestamp('s', tz='UTC'))]),
            index=False
        )

        # write parquet to S3 bucket, under folder for date and file for datetime
        # ex: 2024-06-17/2024-06-17_21:43.gz.parquet
        boto3.client('s3').put_object(
            Bucket='iss-location',
            Key=f"{timestamp.strftime('%Y-%m-%d')}/iss_location_{timestamp.strftime('%Y-%m-%d_%H:%M')}.gz.parquet",
            Body=parquet_buffer.getvalue()
        )
