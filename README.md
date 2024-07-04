# Where is ISS? Hourly ISS position and speed tracking through AWS
Set-up steps below currently work and are to deploy the following to your AWS account:
- S3 buckets required for input / output
- Docker image required for Lambda function to ECR
- Lambda function for daily ISS location ingest from ISS API to S3 bucket
- Eventbridge trigger needed for ISS location data ingestion
- Glue job to compute average hourly speed for ISS from the previous day to another S3 bucket
- Redshift Serverless data warehouse for querying average hourly speed each day

+ All roles and policies required

## Pre-requisites:
1. **Docker engine set-up locally**: https://docs.docker.com/engine/install/
2. **AWS CLI configured for use with your AWS account** (ex: with an access key assigned to your IAM user): https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html

## Set-up:
**The steps below outline how to programatically deploy this project to your AWS account.**

1. Clone this repo to your machine and switch directory to the repo
```
git clone https://github.com/Jason-B-Jiang/where-is-iss.git
cd where-is-iss
```

2. Open config.txt and fill in your AWS region, AWS account ID, as well as desired admin username and password for Redshift data warehouse. For example:
```
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
REDSHIFT_ADMIN_PW=Abcd1234
REDSHIFT_ADMIN_USER=admin
```

3. Run the set-up script to automatically deploy this project, with all necessary AWS resources + IAM roles as needed.
**Important note: certain docker steps in the script run with sudo - please enter your system password whenever prompted**
```
chmod u+x SETUP.sh
./SETUP.sh
```

4. (Optional) Invoke lambda function and Glue job to test
```
# Invoke Lambda function - should write to S3 bucket called "iss-location"
aws lambda invoke --function-name get-iss-position response.json

# Delete json response file
rm response.json

# Invoke Glue job - make note of JobRunId for tracking
# Should write to S3 bucket called "iss-daily-avg-speed"
aws glue start-job-run --job-name iss-daily-avg-speed
aws glue get-job-run --job-name iss-daily-avg-speed --run-id <JobRunId>
```
