#!/bin/bash

BASE_DIR=$(pwd)

# 1. Instantiate config variables for your AWS account
source ./config.txt

# 2. Create S3 bucket, "iss-location", to store ingested ISS location data
aws s3api create-bucket \
--bucket iss-location \
--region ${AWS_REGION} \
--object-ownership BucketOwnerEnforced \
--no-paginate

# 3. Build docker image
cd docker
sudo docker build --platform linux/amd64 -t iss-position-image:v1 .

# 4. Authenticate Docker to Amazon ECR registry
aws ecr get-login-password --region ${AWS_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# 5. Create Amazon ECR repository for the Docker image
aws ecr create-repository --repository-name get-iss-position --region ${AWS_REGION} --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE

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

echo "Waiting for 30 seconds to allow AWS to instantiate lambda function"
sleep 30

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