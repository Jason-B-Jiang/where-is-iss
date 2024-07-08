import boto3

def lambda_handler(event, context):
    query = (
        f"COPY iss_avg_speed FROM 's3://iss-daily-avg-speed/data/' "
        f"IAM_ROLE 'arn:aws:iam::{boto3.client('sts').get_caller_identity()['Account']}:role/RedshiftNamespaceRole' "
        f"FORMAT AS PARQUET;"
        )

    boto3.client('redshift-data').execute_statement(
        Database='dev',
        WorkgroupName='default-workgroup',
        Sql=query
    )