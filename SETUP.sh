#!/bin/bash

BASE_DIR=$(pwd)

# 1. Instantiate config variables for your AWS account
source ./config.txt

# 2. Create S3 bucket, "iss-location", to store ingested ISS location data
# a) iss-location : store daily ingested ISS location data
# b) iss-daily-avg-speed : store computed average hourly speed for the previous day
aws s3api create-bucket \
--bucket iss-location \
--region ${AWS_REGION} \
--object-ownership BucketOwnerEnforced \
--no-paginate

aws s3api create-bucket \
--bucket iss-daily-avg-speed \
--region ${AWS_REGION} \
--object-ownership BucketOwnerEnforced \
--no-paginate

# 3. Build docker image
#    The Docker image is built off AWS's lambda base image for Python 10,
#    and installs all Python dependencies thru pip + includes lambda job in Python
cd docker
sudo docker build --platform linux/amd64 -t iss-position-image:v1 .

# 4. Authenticate Docker to Amazon ECR registry
aws ecr get-login-password --region ${AWS_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# 5. Create Amazon ECR repository for the Docker image
aws ecr create-repository \
--repository-name get-iss-position \
--region ${AWS_REGION} \
--image-scanning-configuration scanOnPush=true \
--image-tag-mutability MUTABLE
--no-paginate

# 6. Tag local docker image as the latest version in your ECR repository
sudo docker tag iss-position-image:v1 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/get-iss-position:latest

# 7. Push local docker image to your ECR repository
sudo docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/get-iss-position:latest

# 8. Create execution role for the lambda function
cd ${BASE_DIR}

aws iam create-role \
--role-name lambda-execute \
--assume-role-policy-document file://resources/lambda-execution-role.json \
--no-paginate

# 9. Assign in-line policy for S3 access (specifically to our bucket) to role
aws iam put-role-policy \
--role-name lambda-execute \
--policy-name allow-s3-bucket-access \
--policy-document file://resources/lambda-execution-role-s3-policy.json \
--no-paginate

# 10. Create a lambda function from the docker image deployed to ECR, and with the execution role
# Also, set time out to 1 min, instead of default 3 seconds
echo "Waiting for 10 seconds to allow AWS to instantiate roles for lambda"
sleep 10

aws lambda create-function \
--function-name get-iss-position \
--package-type Image \
--code ImageUri=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/get-iss-position:latest \
--role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-execute \
--no-paginate

echo "Waiting for 10 seconds to allow AWS to instantiate ISS ingest lambda function"
sleep 10

aws lambda update-function-configuration \
--function-name get-iss-position \
--timeout 60 \
--no-paginate

# 11. Create EventBridge rule to run lambda function hourly
aws events put-rule \
--name trigger-get-iss-position \
--schedule-expression 'cron(0 * ? * * *)' \
--no-paginate

aws lambda add-permission \
--function-name get-iss-position \
--statement-id trigger-get-iss-position-schedule \
--action 'lambda:InvokeFunction' \
--principal events.amazonaws.com \
--source-arn arn:aws:events:${AWS_REGION}:${AWS_ACCOUNT_ID}:rule/trigger-get-iss-position \
--no-paginate

aws events put-targets \
--rule trigger-get-iss-position \
--targets file://resources/targets.json \
--no-paginate

# 12. Set up trust policy for Glue to assume roles, and attach permission to S3 buckets and GlueServiceRole
aws iam create-role --role-name GlueJobRole --assume-role-policy-document file://resources/glue-trust-policy.json --no-paginate

aws iam create-policy --policy-name GlueS3AccessPolicy --policy-document file://resources/glue-s3-policy.json --no-paginate

aws iam attach-role-policy --role-name GlueJobRole --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GlueS3AccessPolicy --no-paginate
aws iam attach-role-policy --role-name GlueJobRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole --no-paginate

# 13. Create glue job for previous day hourly speed from pyspark script, and schedule for 1:30 AM daily
aws s3 cp src/glue_compute_daily_avg_speed.py s3://iss-daily-avg-speed/scripts/glue_compute_daily_avg_speed.py --no-paginate
aws glue create-job --cli-input-json file://resources/glue-job-definition.json --no-paginate
aws glue create-trigger --cli-input-json file://resources/glue-trigger-definition.json --no-paginate

# 14. Set up AWS Redshift Serverless, attaching role with S3 access to created buckets only
aws iam create-role --role-name RedshiftNamespaceRole --assume-role-policy-document file://resources/redshift-trust-policy.json --no-paginate
aws iam create-policy --policy-name RedshiftS3AccessPolicy --policy-document file://resources/redshift-s3-policy.json --no-paginate

aws iam attach-role-policy --role-name RedshiftNamespaceRole --policy-arn arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess --no-paginate
aws iam attach-role-policy --role-name RedshiftNamespaceRole --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/RedshiftS3AccessPolicy --no-paginate

aws redshift-serverless create-namespace \
--admin-user-password ${REDSHIFT_ADMIN_PW} \
--admin-username ${REDSHIFT_ADMIN_USER} \
--db-name dev \
--default-iam-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/RedshiftNamespaceRole \
--iam-roles arn:aws:iam::${AWS_ACCOUNT_ID}:role/RedshiftNamespaceRole \
--namespace-name default-namespace \
--no-paginate

aws redshift-serverless create-workgroup \
--workgroup-name default-workgroup \
--namespace-name default-namespace \
--base-capacity 8 \
--subnet-ids subnet-0bbde0772a82649a6 \
             subnet-012fdbead071327c4 \
             subnet-08f7a557e3280d898 \
             subnet-0c02c3fd2fa457ba8 \
             subnet-078fdc6354ebe1284 \
             subnet-002b340f616290093 \
--security-group-ids sg-0a16fd2da173f43c8 \
--no-enhanced-vpc-routing \
--no-paginate

# 15. Initialize Redshift table for ISS average speed data
aws redshift-data execute-statement \
--database dev \
--workgroup-name default-workgroup \
--sql "CREATE TABLE iss_avg_speed (avg_speed FLOAT, datestamp DATE);" \
--no-paginate

# 16. Create Lambda function triggered by S3 bucket update for average speed,
#     and loading new average speed data into Redshift table.
#
#     Also attach same role as for ingestion Lambda function, but attach
#     additional policy with permissions for Redshift + average speed S3
aws iam put-role-policy \
--role-name lambda-execute \
--policy-name allow-redshift-execute \
--policy-document file://resources/lambda-execution-role-redshift-policy.json \
--no-paginate

cd src
zip update-iss-avg-speed-redshift.zip update_iss_avg_speed_redshift.py
chmod 755 update-iss-avg-speed-redshift.zip
mv update-iss-avg-speed-redshift.zip ${BASE_DIR}/update-iss-avg-speed-redshift.zip
cd ${BASE_DIR}

aws lambda create-function \
--function-name update-iss-avg-speed-redshift \
--runtime python3.10 \
--package-type Zip \
--zip-file fileb://update-iss-avg-speed-redshift.zip \
--handler update_iss_avg_speed_redshift.lambda_handler \
--role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-execute \
--no-paginate

aws lambda update-function-configuration \
--function-name update-iss-avg-speed-redshift \
--timeout 60 \
--no-paginate

aws lambda add-permission --function-name update-iss-avg-speed-redshift \
--principal s3.amazonaws.com \
--statement-id s3 \
--action "lambda:InvokeFunction" \
--source-arn arn:aws:s3:::iss-daily-avg-speed \
--source-account ${AWS_ACCOUNT_ID} \
--no-paginate

aws s3api put-bucket-notification-configuration \
--bucket iss-daily-avg-speed \
--notification-configuration file://resources/s3-lambda-trigger-for-redshift.json