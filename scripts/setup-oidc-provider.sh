#!/bin/bash

# Configuration
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-"255945442255"}
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Check if OIDC provider exists
if ! aws iam list-open-id-connect-providers | grep -q "token.actions.githubusercontent.com"; then
    echo "Creating OIDC provider..."
    
    # Create OIDC provider
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
else
    echo "OIDC provider already exists"
fi

# Update trust policy for the role
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
                    "token.actions.githubusercontent.com:sub": "repo:azniosman/Assignment-3.4:*"
                },
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# Update the role's trust policy
echo "Updating role trust policy..."
aws iam update-assume-role-policy \
    --role-name github-actions-role \
    --policy-document file://trust-policy.json

# Cleanup
rm trust-policy.json

echo "OIDC provider setup complete!" 