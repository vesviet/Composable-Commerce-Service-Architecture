#!/bin/bash
# generate-deployment.sh
# Generates a deployment.yaml from the standard template for a new service
#
# Usage: ./generate-deployment.sh <service-name> <binary-name> [redis-db]
#
# Example: ./generate-deployment.sh pricing-service pricing 2

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <service-name> <binary-name> [redis-db]"
    echo ""
    echo "Arguments:"
    echo "  service-name  : Full service name (e.g., 'pricing-service', 'order-service')"
    echo "  binary-name   : Binary executable name (e.g., 'pricing', 'order')"
    echo "  redis-db      : Redis database index 0-15 (optional, defaults to 0)"
    echo ""
    echo "Example:"
    echo "  $0 pricing-service pricing 2"
    echo ""
    exit 1
fi

SERVICE_NAME="$1"
BINARY_NAME="$2"
REDIS_DB="${3:-0}"

# Convert service-name to SERVICE_PREFIX (uppercase, hyphens to underscores)
SERVICE_PREFIX=$(echo "$SERVICE_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

TEMPLATE_FILE="docs/argocd/STANDARD_DEPLOYMENT_TEMPLATE.yaml"
OUTPUT_DIR="argocd/applications/${SERVICE_NAME}/templates"
OUTPUT_FILE="${OUTPUT_DIR}/deployment.yaml"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Generating deployment.yaml for $SERVICE_NAME..."
echo "  Service Name: $SERVICE_NAME"
echo "  Binary Name:  $BINARY_NAME"
echo "  Prefix:       $SERVICE_PREFIX"
echo "  Redis DB:     $REDIS_DB"
echo "  Output:       $OUTPUT_FILE"
echo ""

# Replace placeholders in template
sed -e "s/<SERVICE_NAME>/${SERVICE_NAME}/g" \
    -e "s/<SERVICE_BINARY>/${BINARY_NAME}/g" \
    -e "s/<SERVICE_PREFIX>/${SERVICE_PREFIX}/g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE.tmp"

# Remove the instructions section (everything after the --- separator)
sed '/^---$/,$d' "$OUTPUT_FILE.tmp" > "$OUTPUT_FILE"
rm "$OUTPUT_FILE.tmp"

echo "✅ Generated: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the generated deployment.yaml"
echo "  2. Update your values.yaml with the standard structure"
echo "  3. Set config.data.redis.db to $REDIS_DB in values.yaml"
echo "  4. Test with: helm template argocd/applications/${SERVICE_NAME}"
echo ""
