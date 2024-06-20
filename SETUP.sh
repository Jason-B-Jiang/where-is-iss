###

# 1. Rewrite steps + code to reflect what you want
# 2. Look into how to assign lambda function S3 access to specific bucket

###

# Pre-req: initialize pass per https://docs.docker.com/desktop/get-started/#credentials-management-for-linux-users
# Enter name and email when prompted to generate key
# Copy public id (pub) generated from gpg command
gpg --generate-key
pass init <generated gpg public id>

# 1. Build docker image
cd docker
sudo docker build --platform linux/amd64 -t iss-position-image:v1 .

# 2. Authenticate Docker to Amazon ECR registry
# AWS account ID can be found by signing into AWS console and clicking on your username
# Note: Docker engine needs to be running for this
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 187594780636.dkr.ecr.us-east-1.amazonaws.com

# 3. Create Amazon ECR repository for the Docker image
# Be sure to copy "repositoryUri" value from output for next step
aws ecr create-repository --repository-name get-iss-position --region us-east-1 --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE

# 4. Tag local docker image as the latest version in your ECR repository
docker tag iss-position-image:v1 187594780636.dkr.ecr.us-east-1.amazonaws.com/get-iss-position:latest

# 5. Push local docker image to your ECR repository
# Log in with the password you set in the pre-req step for your GPG key
docker push 187594780636.dkr.ecr.us-east-1.amazonaws.com/get-iss-position:latest

# 6. Create execution role for the lambda function
# Be sure to copy "Arn" from output for step 8)
aws iam create-role \
--role-name lambda-execute \
--assume-role-policy-document file://../resources/lambda-execution-role.json

# 7. Assign in-line policy for S3 access (specifically to our bucket) to role
aws iam put-role-policy \
--role-name lambda-execute \
--policy-name allow-s3-bucket-access \
--policy-document file://../resources/lambda-execution-role-s3-policy.json

# 8. Create a lambda function from the docker image deployed to ECR, and with the execution role
# Also, set time out to 1 min, instead of default 3 seconds
aws lambda create-function \
--function-name get-iss-position \
--package-type Image \
--code ImageUri=187594780636.dkr.ecr.us-east-1.amazonaws.com/get-iss-position:latest \
--role arn:aws:iam::187594780636:role/lambda-execute

aws lambda update-function-configuration \
  --function-name get-iss-position \
  --timeout 60

# 9. Test lambda function by invoking it
aws lambda invoke --function-name get-iss-position response.json

# 10. Create EventBridge rule to run lambda hourly
aws events put-rule \
--name trigger-get-iss-position \
--schedule-expression 'cron(0 * ? * * *)'

aws lambda add-permission \
--function-name get-iss-position \
--statement-id trigger-get-iss-position-schedule \
--action 'lambda:InvokeFunction' \
--principal events.amazonaws.com \
--source-arn arn:aws:events:us-east-1:187594780636:rule/trigger-get-iss-position

aws events put-targets \
--rule trigger-get-iss-position \
--targets file://../resources/targets.json