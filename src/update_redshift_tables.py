import boto3
from datetime import datetime, timedelta
import time
import json

def lambda_handler(event, context):
    # Get datestamp for previous day
    datestamp = (datetime.today() - timedelta(days=1)).strftime('%Y-%m-%d')

    # Define Redshift queries to run
    account_id = boto3.client('sts').get_caller_identity()['Account']
    iam_role = f"arn:aws:iam::{account_id}:role/lambda-execute"

    # Note: need to get latest file dropped for iss_location, as might not be dropped at exactly 11 PM UTC
    objects = list(boto3.resource('s3').Bucket('iss-location').objects.filter(Prefix=f'{datestamp}/'))
    objects.sort(key=lambda o: o.last_modified)
    latest_file = objects[-1].key

    iss_last_position_query = (
        f"COPY iss_last_position FROM 's3://iss-location/{latest_file}' "
        f"IAM_ROLE '{iam_role}' "
        f"FORMAT AS PARQUET;"
    )
    
    iss_avg_speed_query = (
        f"COPY iss_avg_speed FROM 's3://iss-daily-avg-speed/data/{datestamp}' "
        f"IAM_ROLE '{iam_role}' "
        f"FORMAT AS PARQUET;"
        )

    print(f"Executing query: {iss_last_position_query}")
    print(f"Executing query: {iss_avg_speed_query}")

    client = boto3.client('redshift-data')

    # Execute queries
    responses = []
    queries = [iss_last_position_query, iss_avg_speed_query]

    for query in queries:
        response = client.execute_statement(
            Database='dev',
            WorkgroupName='default-workgroup',
            Sql=query
        )
        responses.append(response)
        print(f"Query Submitted: {response}")

    # Wait and check statuses, ensuring we allow queries to complete before lambda job finishes
    # Lambda by default will be marked as successful after query runs only, but not if it completes
    results = []
    for response in responses:
        status = "SUBMITTED"
        while status in {"SUBMITTED", "PICKED", "STARTED"}:
            time.sleep(2)  # Wait before checking again
            status_response = client.describe_statement(Id=response['Id'])
            status = status_response['Status']
            print(f"Query ID {response['Id']} status: {status}")

            if status == "FAILED":
                print(f"Query failed: {status_response}")
                results.append({
                    "status": "FAILED",
                    "details": status_response
                })
                break

        if status == "FINISHED":
            results.append({
                "status": "SUCCESS",
                "details": response
            })

    # JSON serialize the response
    def json_serial(obj):
        if isinstance(obj, datetime):
            return obj.isoformat()  # Convert datetime to ISO format string
        raise TypeError("Type not serializable")

    return json.loads(json.dumps(results, default=json_serial))