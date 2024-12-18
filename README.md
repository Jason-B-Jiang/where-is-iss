# Where is ISS? Hourly ISS position and speed tracking through AWS

![dashboard_v2](https://github.com/user-attachments/assets/7d19bcc6-6a93-4770-9653-fca0e51df449)

[Google Looker dashboard](https://lookerstudio.google.com/reporting/5fca6f58-4fe8-43ad-868c-a36d7ae87dd6)

## Technical Overview
The project is organized as follows, per the diagram above:
(A) A Lambda function (`get-iss-position`) deployed through a Docker image runs hourly through an EventBridge trigger, pulling GPS location data of the International Space Station via [NASA's Open Notify API](http://open-notify.org/Open-Notify-API/ISS-Location-Now/). The extracted data is deposited as a parquet in a S3 bucket (`iss-position`).

(B) A Glue ETL is triggered by EventBridge at 1:30 AM UTC daily, taking in GPS data *for the previous day* from the `iss-position` S3 bucket, then using PySpark the compute the average hourly speed travelled by the ISS in that previous day. The computed average hourly speed for the previous day is written as a parquet to a separate S3 bucket (`iss-avg-speed`)

(C) Two tables are initialized in a Redshift Serverless data warehouse, `iss_last_position` and `iss-avg-speed`, to query the *previous day's* last recorded location + average hourly speed respectively. A Lambda function is triggered to run everytime the `iss-avg-speed` S3 bucket is updated, inserting the previous day's last recorded location and hourly speed into their respective Redshift tables.

(D) The two Redshift tables feed a Google Looker Studio dashboard, visualizing the trend in average hourly speed in the past week, and the last recorded positions of the ISS in the past three days. **Note that due to the cost of maintaining the Redshift Serverless data warehouse, the dashboard is currently fed by static csv files exported from the Redshift tables before I took down the warehouse.**

The instructions below will deploy all necessary AWS assets + IAM roles / policies required for this project to your AWS account.

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

## Project Caveats / Improvements:
1. Because hourly speed of the ISS is estimated from distance travelled between recorded coordinates, speed estimate is *very* inaccurate as ISS can end up rather close to its previous position if it made close to / past a full orbit in one hour

2. The Glue job for computing average speed for previous day will fail if this project is deployed on or before 1:30 AM UTC, as there will be no previous day location data recorded yet.

3. AWS QuickSight is a more obvious + direct choice for creating a visualization from the Redshift tables, but I opted for Google Looker Studio instead due to the cost of using QuickSight.
