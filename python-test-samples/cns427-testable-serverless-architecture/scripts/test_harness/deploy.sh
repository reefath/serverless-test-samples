#!/bin/bash

# Simple EventBridge Test Infrastructure Deployment
# Run this from anywhere in the project (via make deploy-test-infra)

set -e

echo "🚀 Deploying EventBridge Test Infrastructure..."

# Get script directory and change to infrastructure/test_harness
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT/infrastructure/test_harness"

# Check if CDK is installed
if ! command -v cdk &> /dev/null; then
    echo "❌ Error: CDK is not installed. Install with: npm install -g aws-cdk"
    exit 1
fi

# Set region to us-east-1 (required)
export AWS_DEFAULT_REGION=us-east-1
echo "📍 Using region: us-east-1"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: AWS credentials not configured"
    echo "Set your credentials using the export commands provided"
    exit 1
fi

echo "📦 Installing CDK dependencies..."
pip install aws-cdk-lib constructs boto3 > /dev/null 2>&1 || true

echo "🔍 Testing CDK synthesis..."
if ! cdk synth 2>&1; then
    echo "❌ CDK synthesis failed. Showing error details above."
    echo "💡 Common fixes:"
    echo "   - Install CDK dependencies: pip install aws-cdk-lib constructs boto3"
    echo "   - Check Python version (needs 3.14+)"
    echo "   - Verify stack file syntax"
    exit 1
fi

echo "☁️  Deploying to AWS..."
if cdk deploy --require-approval never; then
    echo "✅ Test infrastructure deployed successfully!"
    
    # Verify deployment
    echo "🔍 Verifying resources..."
    
    if aws dynamodb describe-table --table-name cns427-task-api-test-results > /dev/null 2>&1; then
        echo "✅ DynamoDB table created"
    else
        echo "⚠️  DynamoDB table not found"
    fi
    
    if aws lambda get-function --function-name cns427-task-api-test-subscriber > /dev/null 2>&1; then
        echo "✅ Lambda function created"
    else
        echo "⚠️  Lambda function not found"
    fi
    
    if aws events list-rules --name-prefix cns427-task-api-test | grep -q "cns427-task-api-test-rule"; then
        echo "✅ EventBridge rule created"
    else
        echo "⚠️  EventBridge rule not found"
    fi
    
    echo ""
    echo "🎉 Setup complete! You can now run:"
    echo "   cd ../.."
    echo "   poetry run pytest tests/integration/test_eventbridge_integration.py -v"
    
else
    echo "❌ Deployment failed"
    exit 1
fi