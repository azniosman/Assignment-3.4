#!/bin/bash

# Configuration
AWS_ACCOUNT_ID="255945442255"
AWS_REGION="us-east-1"
REPO_NAME="azni-flask-private-repository"
GITHUB_REPO="azniosman/Assignment-3.4"

# Create trust policy JSON
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
                },
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# Create ECR policy JSON
cat > ecr-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "arn:aws:ecr:${AWS_REGION}:${AWS_ACCOUNT_ID}:repository/${REPO_NAME}"
        }
    ]
}
EOF

# Create IAM role
echo "Creating IAM role..."
aws iam create-role \
    --role-name github-actions-role \
    --assume-role-policy-document file://trust-policy.json

# Create ECR policy
echo "Creating ECR policy..."
aws iam create-policy \
    --policy-name GitHubActionsECRAccess \
    --policy-document file://ecr-policy.json

# Attach policy to role
echo "Attaching policy to role..."
aws iam attach-role-policy \
    --role-name github-actions-role \
    --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsECRAccess

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name github-actions-role --query 'Role.Arn' --output text)
echo "Role ARN: ${ROLE_ARN}"

# Cleanup
rm trust-policy.json ecr-policy.json

echo "Setup complete! Please update your GitHub workflow file with the following Role ARN:"
echo "${ROLE_ARN}" 