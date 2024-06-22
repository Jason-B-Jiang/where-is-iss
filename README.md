# Where is ISS? Hourly ISS position tracking and statistics with Docker and AWS
**WIP! But set-up script is currently ready for your deployment :)**

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

2. Open config.txt and replace region and account number with that for your AWS account. For example:
```
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
```

3. Run the set-up script to automatically deploy this project, with all necessary AWS resources + IAM roles as needed.
**Important note: certain docker steps in the script run with sudo - please enter your system password whenever prompted**
```
chmod u+x SETUP.sh
./SETUP.sh
```

4. (Optional) Invoke lambda function to test, and check if S3 output generated
```
# Invoke lambda function - should write to S3 bucket called "iss-location"
aws lambda invoke --function-name get-iss-position response.json

# Delete json response file
rm response.json
```
