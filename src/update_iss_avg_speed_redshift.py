import boto3
from datetime import datetime, timedelta


def lambda_handler(event, context):
    datestamp = (datetime.today() - timedelta(days=1)).strftime('%Y-%m-%d')

    query = (
        f"COPY iss_avg_speed FROM 's3://iss-daily-avg-speed/data/{datestamp}' "
        f"IAM_ROLE 'arn:aws:iam::{boto3.client('sts').get_caller_identity()['Account']}:role/RedshiftNamespaceRole' "
        f"FORMAT AS PARQUET;"
        )

    response = boto3.client('redshift-data').execute_statement(
        Database='dev',
        WorkgroupName='default-workgroup',
        Sql=query,
        WithEvent=True
    )

    print("Response:", response)
    boto3.client('redshift-data').describe_statement(Id=response['Id'])