#!/usr/bin/env bash
set -Eeuo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------
STACK_NAME="student-three-tier"
AWS_REGION="eu-west-1"
TEMPLATE_BUCKET="cf-3-tier-app-bucket-112334179285-eu-west-1-an"
TEMPLATE_PREFIX="cloudformation-$(date -u +%Y%m%d%H%M%S)"
MAX_ATTEMPTS=60
RETRY_SECONDS=10

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

trap 'echo "ERROR: Deployment failed at line $LINENO. Review the output above."' ERR

# --------------------------------------------------
# Helpers
# --------------------------------------------------
log() {
  printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

get_output() {
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" \
    --output text
}

wait_for_url() {
  local url="$1"
  local description="$2"
  local attempt

  for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    if curl --silent --show-error --fail \
      --connect-timeout 10 --max-time 20 \
      "$url" -o /dev/null; then
      log "$description is responding: $url"
      return 0
    fi

    echo "Waiting for $description ($attempt/$MAX_ATTEMPTS)..."
    sleep "$RETRY_SECONDS"
  done

  echo "ERROR: $description did not become healthy: $url"
  return 1
}

# --------------------------------------------------
# Prerequisites
# --------------------------------------------------
log "Checking local tools and AWS credentials..."

for cmd in aws curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: Required command is missing: $cmd"
    exit 1
  }
done

aws sts get-caller-identity --region "$AWS_REGION"

for file in \
  main.yaml \
  infra/network.yaml \
  infra/security.yaml \
  infra/database.yaml \
  infra/compute.yaml \
  infra/s3-website.yaml \
  website/index.html \
  website/app.js; do
  [[ -f "$file" ]] || {
    echo "ERROR: Required file not found: $file"
    exit 1
  }
done

[[ -d website ]] || {
  echo "ERROR: website/ directory was not found."
  exit 1
}

aws s3api head-bucket \
  --bucket "$TEMPLATE_BUCKET" \
  --region "$AWS_REGION"

# --------------------------------------------------
# Validate templates
# --------------------------------------------------
log "Validating CloudFormation templates..."

for file in \
  main.yaml \
  infra/network.yaml \
  infra/security.yaml \
  infra/database.yaml \
  infra/compute.yaml \
  infra/s3-website.yaml; do
  echo "Validating $file"
  aws cloudformation validate-template \
    --template-body "file://$file" \
    --region "$AWS_REGION" >/dev/null
done

# --------------------------------------------------
# Check existing CloudFormation stack
# --------------------------------------------------
log "Checking existing CloudFormation stack..."

if STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>&1); then
  echo "Existing stack status: $STACK_STATUS"
else
  DESCRIBE_ERROR="$STACK_STATUS"

  if grep -Eqi \
    'ValidationError.*Stack with id .* does not exist|Stack with id .* does not exist' \
    <<< "$DESCRIBE_ERROR"; then
    STACK_STATUS="NOT_FOUND"
    echo "No existing stack found. A fresh deployment will create it."
  else
    echo "ERROR: Unable to determine CloudFormation stack status."
    printf '%s\n' "$DESCRIBE_ERROR"
    exit 1
  fi
fi

case "$STACK_STATUS" in
  NOT_FOUND)
    echo "Proceeding with fresh stack creation."
    ;;
  CREATE_COMPLETE|UPDATE_COMPLETE|UPDATE_ROLLBACK_COMPLETE)
    echo "Existing stack is in a supported state: $STACK_STATUS"
    ;;
  *)
    echo "ERROR: Stack is not in a supported state: $STACK_STATUS"
    echo "Resolve the stack state before deploying."
    exit 1
    ;;
esac

# --------------------------------------------------
# Upload nested templates
# --------------------------------------------------
log "Uploading nested CloudFormation templates..."

aws s3 cp infra/ \
  "s3://${TEMPLATE_BUCKET}/${TEMPLATE_PREFIX}/infra/" \
  --recursive \
  --exclude "*" \
  --include "*.yaml" \
  --region "$AWS_REGION"

# --------------------------------------------------
# Deploy the root stack (creates it if absent, updates if present)
# --------------------------------------------------
log "Deploying stack: $STACK_NAME"

aws cloudformation deploy \
  --template-file main.yaml \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    "TemplateBucket=${TEMPLATE_BUCKET}" \
    "TemplatePrefix=${TEMPLATE_PREFIX}" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --region "$AWS_REGION"

STACK_STATUS="$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text)"

[[ "$STACK_STATUS" == "CREATE_COMPLETE" ||
   "$STACK_STATUS" == "UPDATE_COMPLETE" ]] || {
  echo "ERROR: Stack did not finish successfully: $STACK_STATUS"
  exit 1
}

log "CloudFormation stack completed successfully."

# --------------------------------------------------
# Read stack outputs
# --------------------------------------------------
BUCKET_NAME="$(get_output WebsiteBucketName)"
DISTRIBUTION_ID="$(get_output DistributionId)"
WEBSITE_URL="$(get_output WebsiteURL)"
INSTANCE_ID="$(get_output ApiInstanceId)"

for name in BUCKET_NAME DISTRIBUTION_ID WEBSITE_URL INSTANCE_ID; do
  value="${!name}"
  [[ -n "$value" && "$value" != "None" ]] || {
    echo "ERROR: Missing CloudFormation output: $name"
    exit 1
  }
done

# --------------------------------------------------
# Generate website configuration
# --------------------------------------------------
log "Generating website/config.js..."

cat > website/config.js <<'JSCONFIG'
/* API requests use the same CloudFront domain. */
const API_BASE_URL = '';
JSCONFIG

# --------------------------------------------------
# Publish frontend
# --------------------------------------------------
log "Uploading website files to S3: $BUCKET_NAME"

aws s3 sync website/ \
  "s3://${BUCKET_NAME}/" \
  --region "$AWS_REGION"

# --------------------------------------------------
# Wait for EC2 to register with Systems Manager
# --------------------------------------------------
log "Waiting for EC2 instance to become available in Systems Manager..."

SSM_ONLINE=""

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  SSM_ONLINE="$(aws ssm describe-instance-information \
    --region "$AWS_REGION" \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query "InstanceInformationList[?PingStatus=='Online'].InstanceId | [0]" \
    --output text)"

  if [[ "$SSM_ONLINE" == "$INSTANCE_ID" ]]; then
    break
  fi

  echo "Waiting for SSM agent registration ($attempt/$MAX_ATTEMPTS)..."
  sleep "$RETRY_SECONDS"
done

[[ "$SSM_ONLINE" == "$INSTANCE_ID" ]] || {
  echo "ERROR: EC2 did not become online in Systems Manager."
  echo "Check the instance role, SSM agent, network access and UserData logs."
  exit 1
}

# --------------------------------------------------
# Ensure dependency and service on the current instance
# --------------------------------------------------
log "Ensuring API dependencies are installed on EC2..."

COMMAND_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --comment "Ensure three-tier API dependencies and service are ready" \
  --parameters '{
    "commands": [
      "set -eu",
      "/opt/three-tier/venv/bin/pip install cryptography==44.0.3",
      "systemctl restart three-tier",
      "systemctl is-active --quiet three-tier",
      "/opt/three-tier/venv/bin/python -c \"import cryptography, pymysql, flask; print(\\\"Required Python packages are installed\\\")\""
    ]
  }' \
  --region "$AWS_REGION" \
  --query 'Command.CommandId' \
  --output text)"

log "Waiting for the EC2 setup command to complete..."

if ! aws ssm wait command-executed \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$AWS_REGION"; then
  echo "ERROR: SSM setup command failed."
  aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query '{Status:Status,Output:StandardOutputContent,Error:StandardErrorContent}' \
    --output json || true
  exit 1
fi

aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query '{Status:Status,Output:StandardOutputContent}' \
  --output json

# --------------------------------------------------
# Invalidate CloudFront cache and wait for completion
# --------------------------------------------------
log "Creating CloudFront invalidation..."

INVALIDATION_ID="$(aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*" \
  --query 'Invalidation.Id' \
  --output text)"

log "Waiting for CloudFront invalidation: $INVALIDATION_ID"

aws cloudfront wait invalidation-completed \
  --distribution-id "$DISTRIBUTION_ID" \
  --id "$INVALIDATION_ID"

# --------------------------------------------------
# Verify public website and database-backed API
# --------------------------------------------------
log "Testing public website..."

wait_for_url "${WEBSITE_URL%/}/" "Website"

log "Checking published frontend configuration..."

CONFIG_CONTENT="$(curl --silent --show-error --fail \
  --connect-timeout 10 --max-time 20 \
  "${WEBSITE_URL%/}/config.js")"

if ! grep -Fq "const API_BASE_URL = '';" <<< "$CONFIG_CONTENT"; then
  echo "ERROR: Published config.js does not contain the expected API base URL."
  printf '%s\n' "$CONFIG_CONTENT"
  exit 1
fi

log "Testing database-backed API through CloudFront..."

wait_for_url "${WEBSITE_URL%/}/api/messages" "Database-backed API"

API_RESPONSE="$(curl --silent --show-error --fail \
  --connect-timeout 10 --max-time 20 \
  "${WEBSITE_URL%/}/api/messages")"

if ! python3 -c '
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list):
    raise SystemExit("API response is not a JSON array")
print("API returned a valid JSON message list.")
' <<< "$API_RESPONSE"; then
  echo "ERROR: API response did not contain a valid JSON message list."
  printf '%s\n' "$API_RESPONSE"
  exit 1
fi

# --------------------------------------------------
# Report successful deployment
# --------------------------------------------------
echo
echo "=========================================="
echo "DEPLOYMENT AND SMOKE TESTS SUCCEEDED"
echo "=========================================="
echo "Stack:          $STACK_NAME"
echo "Stack status:   $STACK_STATUS"
echo "Website URL:    $WEBSITE_URL"
echo "S3 bucket:      $BUCKET_NAME"
echo "EC2 instance:   $INSTANCE_ID"
echo "Distribution:   $DISTRIBUTION_ID"
echo "Invalidation:   $INVALIDATION_ID"
echo "Website test:   PASSED"
echo "Config test:    PASSED"
echo "API/DB test:    PASSED"
echo
echo "Connect to EC2 without SSH:"
echo "aws ssm start-session --target $INSTANCE_ID --region $AWS_REGION"
echo
