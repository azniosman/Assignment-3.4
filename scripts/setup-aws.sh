#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-"255945442255"}
AWS_REGION=${AWS_REGION:-"us-east-1"}
REPO_NAME=${REPO_NAME:-"azni-flask-private-repository"}
GITHUB_REPO=${GITHUB_REPO:-"azniosman/Assignment-3.4"}

# Error handling function
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Check AWS CLI installation
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        handle_error "AWS CLI is not installed. Please install it first."
    fi
}

# Check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        handle_error "AWS credentials are not configured. Please run 'aws configure' first."
    fi
}

# Setup OIDC provider
setup_oidc_provider() {
    echo -e "${YELLOW}Setting up OIDC provider...${NC}"
    
    if ! aws iam list-open-id-connect-providers | grep -q "token.actions.githubusercontent.com"; then
        echo "Creating OIDC provider..."
        aws iam create-open-id-connect-provider \
            --url https://token.actions.githubusercontent.com \
            --client-id-list sts.amazonaws.com \
            --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 || handle_error "Failed to create OIDC provider"
    else
        echo -e "${GREEN}OIDC provider already exists${NC}"
    fi
}

# Setup IAM role
setup_iam_role() {
    echo -e "${YELLOW}Setting up IAM role...${NC}"
    
    # Create trust policy
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

    # Create ECR policy
    cat > ecr-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
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
    if ! aws iam get-role --role-name github-actions-role &> /dev/null; then
        echo "Creating IAM role..."
        aws iam create-role \
            --role-name github-actions-role \
            --assume-role-policy-document file://trust-policy.json || handle_error "Failed to create IAM role"
    else
        echo "Updating IAM role trust policy..."
        aws iam update-assume-role-policy \
            --role-name github-actions-role \
            --policy-document file://trust-policy.json || handle_error "Failed to update IAM role trust policy"
    fi

    # Create and attach ECR policy
    if ! aws iam get-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsECRAccess &> /dev/null; then
        echo "Creating ECR policy..."
        aws iam create-policy \
            --policy-name GitHubActionsECRAccess \
            --policy-document file://ecr-policy.json || handle_error "Failed to create ECR policy"
    else
        echo "Updating ECR policy..."
        aws iam create-policy-version \
            --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsECRAccess \
            --policy-document file://ecr-policy.json \
            --set-as-default || handle_error "Failed to update ECR policy"
    fi

    echo "Attaching ECR policy to role..."
    aws iam attach-role-policy \
        --role-name github-actions-role \
        --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsECRAccess || handle_error "Failed to attach ECR policy"

    # Get and display role ARN
    ROLE_ARN=$(aws iam get-role --role-name github-actions-role --query 'Role.Arn' --output text)
    echo -e "${GREEN}Role ARN: ${ROLE_ARN}${NC}"

    # Cleanup
    rm trust-policy.json ecr-policy.json
}

# Main menu
show_menu() {
    echo -e "\n${YELLOW}AWS Setup Menu${NC}"
    echo "1. Setup OIDC Provider"
    echo "2. Setup IAM Role"
    echo "3. Setup Both (OIDC Provider and IAM Role)"
    echo "4. Exit"
    echo -n "Enter your choice [1-4]: "
}

# Main function
main() {
    check_aws_cli
    check_aws_credentials

    while true; do
        show_menu
        read choice
        case $choice in
            1)
                setup_oidc_provider
                ;;
            2)
                setup_iam_role
                ;;
            3)
                setup_oidc_provider
                setup_iam_role
                ;;
            4)
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
    done
}

# Run main function
main 