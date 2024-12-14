import boto3
from datetime import datetime, timedelta


def lambda_handler(event, context):
    # Get datestamp for previous day, as Redshift tables reflect last recorded position
    # and average hourly speed for the previous day
    datestamp = (datetime.today() - timedelta(days=1)).strftime('%Y-%m-%d')

    # Define Redshift queries for each table:
    # iss_last_location: pull last recorded location for ISS from the previous day (i.e: 11 PM)
    # iss_avg_speed: pull computed average hourly speed for ISS from the previous day
    iss_last_position_query = (
        f"COPY iss_last_position FROM 's3://iss-location/{datestamp}/iss_location_{datestamp}_23:00.gz.parquet' "
        f"IAM_ROLE 'arn:aws:iam::{boto3.client('sts').get_caller_identity()['Account']}:role/RedshiftNamespaceRole' "
        f"FORMAT AS PARQUET;"
        )

    iss_avg_speed_query = (
        f"COPY iss_avg_speed FROM 's3://iss-daily-avg-speed/data/{datestamp}' "
        f"IAM_ROLE 'arn:aws:iam::{boto3.client('sts').get_caller_identity()['Account']}:role/RedshiftNamespaceRole' "
        f"FORMAT AS PARQUET;"
        )
    
    # Execute Redshift queries
    client = boto3.client('redshift-data')

    iss_last_position_response = client.execute_statement(
        Database='dev',
        WorkgroupName='default-workgroup',
        Sql=iss_last_position_query,
        withEvent=True
    )

    iss_avg_speed_response = client.execute_statement(
        Database='dev',
        WorkgroupName='default-workgroup',
        Sql=iss_avg_speed_query,
        withEvent=True
    )

    # Send response outputs to Cloudwatch log for this lambda job
    print("Response:", iss_last_position_response)
    print("Response:", iss_avg_speed_response)

    client.describe_statement(Id=iss_last_position_response['Id'])
    client.describe_statement(Id=iss_avg_speed_response['Id'])