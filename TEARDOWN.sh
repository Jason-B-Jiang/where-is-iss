#!/bin/bash

# 1. Instantiate config variables for your AWS account
source ./config.txt

# 2. Teardown Lambda function for updating Redshift data warehouse
aws lambda delete-function \
--function-name update-iss-avg-speed-redshift \
--no-paginate

# 3. Teardown Redshift Serverless namespace + workgroup
#    Allow 2 mins for workgroup to be fully deleted
aws redshift-serverless delete-workgroup \
--workgroup-name default-workgroup \
--no-paginate

sleep 120

aws redshift-serverless delete-namespace \
--namespace-name default-namespace \
--no-paginate

# 4. Teardown Glue job for ISS hourly average speed
aws glue delete-job \
--job-name iss-daily-avg-speed \
--no-paginate

# 5. Teardown Lambda function for hourly ISS location ingest
aws lambda delete-function \
--function-name get-iss-position \
--no-paginate

# 6. Teardown all S3 buckets
aws s3 rm s3://iss-location --recursive
aws s3 rb s3://iss-location --force

aws s3 rm s3://iss-daily-avg-speed --recursive
aws s3 rb s3://iss-daily-avg-speed --force

# 7. Teardown all created IAM roles & polices

# a) delete inline policies from all created roles
aws iam delete-role-policy \
--role-name lambda-execute \
--policy-name allow-redshift-execute

aws iam delete-role-policy \
--role-name lambda-execute \
--policy-name allow-s3-bucket-access

# b) detach managed policies from all created roles
aws iam detach-role-policy \
--role-name GlueJobRole \
--policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

aws iam detach-role-policy \
--role-name GlueJobRole \
--policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GlueS3AccessPolicy

aws iam detach-role-policy \
--role-name RedshiftNamespaceRole \
--policy-arn arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess

aws iam detach-role-policy \
--role-name RedshiftNamespaceRole \
--policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/RedshiftS3AccessPolicy

# c) delete managed policies created by us
aws iam delete-policy \
--policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GlueS3AccessPolicy

aws iam delete-policy \
--policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/RedshiftS3AccessPolicy

# d) delete all created roles
aws iam delete-role \
--role-name lambda-execute

aws iam delete-role \
--role-name GlueJobRole

aws iam delete-role \
--role-name RedshiftNamespaceRole

# 8. Teardown docker image for ISS location ingest lambda

# 9. Teardown Eventbridge trigger for hourly ISS location lambda