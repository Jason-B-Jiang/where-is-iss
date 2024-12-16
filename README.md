# Where is ISS? Hourly ISS position and speed tracking through AWS

![dashboard](https://github.com/user-attachments/assets/d07c8a9a-a3cb-4001-8884-681ca4cde891)
Google Looker dashboard: https://lookerstudio.google.com/reporting/5fca6f58-4fe8-43ad-868c-a36d7ae87dd6

## Technical Overview
Set-up steps below currently work and are to deploy the following to your AWS account:
- S3 buckets required for input / output
- Docker image required for Lambda function to ECR
- Lambda function for daily ISS location ingest from ISS API to S3 bucket
- Eventbridge trigger needed for ISS location data ingestion
- Glue job to compute average hourly speed for ISS from the previous day to another S3 bucket
- Redshift Serverless data warehouse for querying average hourly speed each day
- Google Looker Studio dashboard connected to Redshift to show average speeds and last recorded positions*

+ All roles and policies required

* NOTE: due to costs of hosting Redshift warehouse, dashboard is currently connected to static csv files exported from Redshift for cost efficiency.

## Pre-requisites:
1. **Docker engine set-up locally**: https://docs.docker.com/engine/install/
2. **AWS CLI configured for use with your AWS account** (ex: with an access key assigned to your IAM user): https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html

## Set-up:
**These steps outline how to programatically deploy this project to your AWS account.**

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

## Teardown:
**This will remove ALL assets created on your AWS account during set-up (ex: IAM roles, policies, Lambda functions, S3 buckets, etc).**
1. Run teardown script to automatically delete all AWS assets created
```
chmod u+x TEARDOWN.sh
./TEARDOWN.sh
```
