# 1. Instantiate config variables for your AWS account
source ./config.txt

# 2 Build docker image
cd docker
docker build --platform linux/amd64 -t iss-position-image:v1 .

# 3. Authenticate Docker to Amazon ECR registry
aws ecr get-login-password --region ${AWS_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# 4. Create Amazon ECR repository for the Docker image
# Be sure to copy "repositoryUri" value from output for next step
aws ecr create-repository --repository-name get-iss-position --region ${AWS_REGION} --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE

# 5. Tag local docker image as the latest version in your ECR repository
docker tag iss-position-image:v1 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/get-iss-position:latest

# 6. Push local docker image to your ECR repository
# Log in with the password you set in the pre-req step for your GPG key
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/get-iss-position:latest

# 7. Create execution role for the lambda function
# Be sure to copy "Arn" from output for step 8)
aws iam create-role \
--role-name lambda-execute \
--assume-role-policy-document file://../resources/lambda-execution-role.json

# 8. Assign in-line policy for S3 access (specifically to our bucket) to role
aws iam put-role-policy \
--role-name lambda-execute \
--policy-name allow-s3-bucket-access \
--policy-document file://../resources/lambda-execution-role-s3-policy.json

# 9. Create a lambda function from the docker image deployed to ECR, and with the execution role
# Also, set time out to 1 min, instead of default 3 seconds
aws lambda create-function \
--function-name get-iss-position \
--package-type Image \
--code ImageUri=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/get-iss-position:latest \
--role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-execute

aws lambda update-function-configuration \
  --function-name get-iss-position \
  --timeout 60

# 10. Create EventBridge rule to run lambda function hourly
aws events put-rule \
--name trigger-get-iss-position \
--schedule-expression 'cron(0 * ? * * *)'

aws lambda add-permission \
--function-name get-iss-position \
--statement-id trigger-get-iss-position-schedule \
--action 'lambda:InvokeFunction' \
--principal events.amazonaws.com \
--source-arn arn:aws:events:${AWS_REGION}:${AWS_ACCOUNT_ID}:rule/trigger-get-iss-position

aws events put-targets \
--rule trigger-get-iss-position \
--targets file://../resources/targets.json