# where-is-iss

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
