#!/bin/bash

# This is the master key for this demo.
RAILS_MASTER_KEY="743c44757a18175254895f68b1369aa5"

AWS_IDENTITY=$(aws sts get-caller-identity)
AWS_ACCOUNT_ID=$(echo ${AWS_IDENTITY} | jq -r ".Account")

REGION="ap-northeast-1"
SERVICE_NAME="serverless-rails-sample"
STAGE_ENV="demo"
CODECOMMIT_REPO_NAME=${SERVICE_NAME}
CODECOMMIT_BRANCH="master"
CODEBUILD_PROJ_NAME="${SERVICE_NAME}-${STAGE_ENV}"
SERVICE_STACK_NAME="${SERVICE_NAME}-${STAGE_ENV}"
ECR_REPO_NAME=${SERVICE_NAME}
ROLE_BUILD_NAME="${SERVICE_NAME}-build"
ROLE_EXECUTE_NAME="${SERVICE_NAME}-execute"
BUCKET_DEPLOY_NAME="${SERVICE_NAME}-deploy-bucket"
DYNAMO_PREFIX="${SERVICE_NAME}-${STAGE_ENV}"

rm -rf work
mkdir work
cd ./work

## Create CodeCommit repository
aws codecommit create-repository --repository-name ${CODECOMMIT_REPO_NAME}
git clone --mirror https://github.com/nihemak/serverless-rails-sample.git
cd serverless-rails-sample
git push ssh://git-codecommit.${REGION}.amazonaws.com/v1/repos/${CODECOMMIT_REPO_NAME} --all
cd ..

## Create DynamoDB table
aws dynamodb create-table --table-name ${DYNAMO_PREFIX}-todos \
                          --attribute-definitions AttributeName=id,AttributeType=S \
                          --key-schema AttributeName=id,KeyType=HASH \
                          --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

## Create IAM lambda execute role
cat <<EOF > Trust-Policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
ROLE_EXECUTE=$(aws iam create-role --role-name ${ROLE_EXECUTE_NAME} \
                                   --assume-role-policy-document file://Trust-Policy.json)
ROLE_EXECUTE_ARN=$(echo ${ROLE_EXECUTE} | jq -r ".Role.Arn")
cat <<EOF > Permissions.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${REGION}:${AWS_ACCOUNT_ID}:log-group:/aws/lambda/${SERVICE_NAME}-*"
            ],
            "Effect": "Allow"
        },
        {
            "Action": [
                "dynamodb:DescribeTable",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteItem"
            ],
            "Resource": "arn:aws:dynamodb:${REGION}:${AWS_ACCOUNT_ID}:table/${DYNAMO_PREFIX}-*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "dynamodb:ListTables"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
aws iam put-role-policy \
        --role-name ${ROLE_EXECUTE_NAME} \
        --policy-name ${ROLE_EXECUTE_NAME} \
        --policy-document file://Permissions.json

## Create S3 deploy bucket
aws s3 mb s3://${BUCKET_DEPLOY_NAME} --region ${REGION}

## Create ECR build image repository
ECR_LOGIN=$(aws ecr get-login --no-include-email)
echo ${ECR_LOGIN} > ecr_login.sh
chmod 755 ecr_login.sh
bash ./ecr_login.sh

ECR_REPO=$(aws ecr create-repository --repository-name ${ECR_REPO_NAME})
ECR_REPO_URL=$(echo ${ECR_REPO} | jq -r ".repository.repositoryUri")

docker pull lambci/lambda:build-ruby2.5
docker tag lambci/lambda:build-ruby2.5 ${ECR_REPO_URL}:latest
docker push ${ECR_REPO_URL}:latest

cat <<EOF > ecr_policy.json
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "CodeBuildAccess",
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ]
        }
    ]
}
EOF
aws ecr set-repository-policy --repository-name ${ECR_REPO_NAME} --policy-text file://ecr_policy.json

## Create IAM build role
cat <<EOF > Trust-Policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
ROLE_BUILD=$(aws iam create-role --role-name ${ROLE_BUILD_NAME} \
                                 --assume-role-policy-document file://Trust-Policy.json)
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
                           --role-name ${ROLE_BUILD_NAME}
ROLE_BUILD_ARN=$(echo ${ROLE_BUILD} |jq -r ".Role.Arn")

## Create CodeBuild
cat <<EOF > Source.json
{
  "type": "CODECOMMIT",
  "location": "https://git-codecommit.${REGION}.amazonaws.com/v1/repos/${CODECOMMIT_REPO_NAME}",
  "buildspec": "buildspec.yml"
}
EOF
cat <<EOF > Artifacts.json
{
  "type": "NO_ARTIFACTS"
}
EOF
cat <<EOF > Environment.json
{
  "type": "LINUX_CONTAINER",
  "image": "${ECR_REPO_URL}:latest",
  "computeType": "BUILD_GENERAL1_SMALL",
  "environmentVariables": [
    {
      "name": "REGION",
      "value": "${REGION}",
      "type": "PLAINTEXT"
    },
    {
      "name": "STAGE_ENV",
      "value": "${STAGE_ENV}",
      "type": "PLAINTEXT"
    },
    {
      "name": "SERVICE_NAME",
      "value": "${SERVICE_NAME}",
      "type": "PLAINTEXT"
    },
    {
      "name": "LAMBDA_ROLE",
      "value": "${ROLE_EXECUTE_ARN}",
      "type": "PLAINTEXT"
    },
    {
      "name": "DEPLOY_BUCKET",
      "value": "${BUCKET_DEPLOY_NAME}",
      "type": "PLAINTEXT"
    },
    {
      "name": "DYNAMO_PREFIX",
      "value": "${DYNAMO_PREFIX}",
      "type": "PLAINTEXT"
    },
    {
      "name": "RAILS_ENV",
      "value": "production",
      "type": "PLAINTEXT"
    },
    {
      "name": "RAILS_MASTER_KEY",
      "value": "${RAILS_MASTER_KEY}",
      "type": "PLAINTEXT"
    }
  ]
}
EOF
aws codebuild create-project --name ${CODEBUILD_PROJ_NAME} \
                               --source file://Source.json \
                               --artifacts file://Artifacts.json \
                               --environment file://Environment.json \
                               --service-role ${ROLE_BUILD_ARN}

## Create Lambda and API Gateway
aws codebuild start-build --project-name ${CODEBUILD_PROJ_NAME} \
                          --source-version ${CODECOMMIT_BRANCH}
REST_API_ID=$(aws cloudformation describe-stack-resources --stack-name ${SERVICE_STACK_NAME} | jq -r '.StackResources[] | select(.ResourceType == "AWS::ApiGateway::RestApi") | .PhysicalResourceId')
REST_API_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id ${REST_API_ID} | jq -r '.items[] | select(.path == "/{proxy+}") | .id')

## GET /todos
aws apigateway test-invoke-method --rest-api-id ${REST_API_ID} \
                                  --resource-id ${REST_API_RESOURCE_ID} \
                                  --http-method GET \
                                  --path-with-query-string '/todos' \
                                  --headers 'Content-Type=application/json,charset=utf-8'
# curl -X GET https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_ENV}/todos

## POST /todos
aws apigateway test-invoke-method --rest-api-id ${REST_API_ID} \
                                  --resource-id ${REST_API_RESOURCE_ID} \
                                  --http-method POST \
                                  --path-with-query-string '/todos?text=foo' \
                                  --headers 'Content-Type=application/json,charset=utf-8'
# curl -X POST https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_ENV}/todos --data "text=foo"

TODO_ID=$(aws apigateway test-invoke-method --rest-api-id ${REST_API_ID} \
                                            --resource-id ${REST_API_RESOURCE_ID} \
                                            --http-method GET \
                                            --path-with-query-string '/todos' \
                                            --headers 'Content-Type=application/json,charset=utf-8' | jq -r '.body' | jq -r '.[].id')
# TODO_ID=$(curl -X GET https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_ENV}/todos | jq -r '.[].id')

## GET /todos/:id
aws apigateway test-invoke-method --rest-api-id ${REST_API_ID} \
                                  --resource-id ${REST_API_RESOURCE_ID} \
                                  --http-method GET \
                                  --path-with-query-string "/todos/${TODO_ID}" \
                                  --headers 'Content-Type=application/json,charset=utf-8'
# curl -X GET https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_ENV}/todos/${TODO_ID}

## PUT /todos/:id
aws apigateway test-invoke-method --rest-api-id ${REST_API_ID} \
                                  --resource-id ${REST_API_RESOURCE_ID} \
                                  --http-method PUT \
                                  --path-with-query-string "/todos/${TODO_ID}?text=bar" \
                                  --headers 'Content-Type=application/json,charset=utf-8'
# curl -X PUT https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_ENV}/todos/${TODO_ID}?text=bar

## DELETE /todos/:id
aws apigateway test-invoke-method --rest-api-id ${REST_API_ID} \
                                  --resource-id ${REST_API_RESOURCE_ID} \
                                  --http-method DELETE \
                                  --path-with-query-string "/todos/${TODO_ID}" \
                                  --headers 'Content-Type=application/json,charset=utf-8'
# curl -X DELETE https://${REST_API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_ENV}/todos/${TODO_ID}
