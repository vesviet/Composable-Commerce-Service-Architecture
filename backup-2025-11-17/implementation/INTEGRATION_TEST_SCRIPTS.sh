#!/bin/bash

# Integration Test Scripts for Address Reuse Hybrid Approach
# Usage: ./INTEGRATION_TEST_SCRIPTS.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CUSTOMER_SERVICE_URL="${CUSTOMER_SERVICE_URL:-http://localhost:8080/api/customer}"
ORDER_SERVICE_URL="${ORDER_SERVICE_URL:-http://localhost:8080/api/order}"
AUTH_TOKEN="${AUTH_TOKEN:-}"

# Test customer and product IDs (should be created beforehand)
TEST_CUSTOMER_ID="${TEST_CUSTOMER_ID:-}"
TEST_PRODUCT_ID="${TEST_PRODUCT_ID:-}"

echo -e "${YELLOW}=== Address Reuse Hybrid Approach Integration Tests ===${NC}\n"

# Helper function to make API calls
api_call() {
    local method=$1
    local url=$2
    local data=$3
    local token=$4
    
    if [ -z "$token" ]; then
        curl -s -X "$method" "$url" \
            -H "Content-Type: application/json" \
            ${data:+-d "$data"}
    else
        curl -s -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            ${data:+-d "$data"}
    fi
}

# Test 1: Create Customer Address
echo -e "${YELLOW}Test 1: Create Customer Address${NC}"
CREATE_ADDRESS_RESPONSE=$(api_call POST \
    "$CUSTOMER_SERVICE_URL/v1/customers/$TEST_CUSTOMER_ID/addresses" \
    '{
        "type": "ADDRESS_TYPE_SHIPPING",
        "first_name": "John",
        "last_name": "Doe",
        "address_line_1": "123 Main St",
        "city": "New York",
        "state_province": "NY",
        "postal_code": "10001",
        "country_code": "US",
        "phone": "123-456-7890",
        "is_default": true
    }' \
    "$AUTH_TOKEN")

ADDRESS_ID=$(echo "$CREATE_ADDRESS_RESPONSE" | jq -r '.address.id // empty')

if [ -z "$ADDRESS_ID" ] || [ "$ADDRESS_ID" == "null" ]; then
    echo -e "${RED}✗ FAIL: Could not create address${NC}"
    echo "Response: $CREATE_ADDRESS_RESPONSE"
    exit 1
else
    echo -e "${GREEN}✓ PASS: Address created with ID: $ADDRESS_ID${NC}"
fi

# Test 2: Get Customer Addresses
echo -e "\n${YELLOW}Test 2: Get Customer Addresses${NC}"
GET_ADDRESSES_RESPONSE=$(api_call GET \
    "$CUSTOMER_SERVICE_URL/v1/customers/$TEST_CUSTOMER_ID/addresses" \
    "" \
    "$AUTH_TOKEN")

ADDRESS_COUNT=$(echo "$GET_ADDRESSES_RESPONSE" | jq '.addresses | length')

if [ "$ADDRESS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ PASS: Retrieved $ADDRESS_COUNT address(es)${NC}"
else
    echo -e "${RED}✗ FAIL: No addresses found${NC}"
    exit 1
fi

# Test 3: Create Order with Customer Address ID
echo -e "\n${YELLOW}Test 3: Create Order with Customer Address ID${NC}"
CREATE_ORDER_RESPONSE=$(api_call POST \
    "$ORDER_SERVICE_URL/v1/orders" \
    "{
        \"user_id\": \"$TEST_CUSTOMER_ID\",
        \"items\": [
            {
                \"product_id\": \"$TEST_PRODUCT_ID\",
                \"product_sku\": \"SKU-001\",
                \"quantity\": 2
            }
        ],
        \"customer_shipping_address_id\": \"$ADDRESS_ID\",
        \"customer_billing_address_id\": \"$ADDRESS_ID\",
        \"payment_method\": \"credit_card\"
    }" \
    "$AUTH_TOKEN")

ORDER_ID=$(echo "$CREATE_ORDER_RESPONSE" | jq -r '.order.id // empty')

if [ -z "$ORDER_ID" ] || [ "$ORDER_ID" == "null" ]; then
    echo -e "${RED}✗ FAIL: Could not create order${NC}"
    echo "Response: $CREATE_ORDER_RESPONSE"
    exit 1
else
    echo -e "${GREEN}✓ PASS: Order created with ID: $ORDER_ID${NC}"
fi

# Test 4: Get Order and Verify Address
echo -e "\n${YELLOW}Test 4: Get Order and Verify Address${NC}"
GET_ORDER_RESPONSE=$(api_call GET \
    "$ORDER_SERVICE_URL/v1/orders/$ORDER_ID" \
    "" \
    "$AUTH_TOKEN")

SHIPPING_ADDRESS=$(echo "$GET_ORDER_RESPONSE" | jq '.order.shipping_address // empty')

if [ -z "$SHIPPING_ADDRESS" ] || [ "$SHIPPING_ADDRESS" == "null" ]; then
    echo -e "${RED}✗ FAIL: Order does not have shipping address${NC}"
    exit 1
else
    ADDRESS_FIRST_NAME=$(echo "$SHIPPING_ADDRESS" | jq -r '.first_name // empty')
    if [ "$ADDRESS_FIRST_NAME" == "John" ]; then
        echo -e "${GREEN}✓ PASS: Order address matches customer address${NC}"
    else
        echo -e "${RED}✗ FAIL: Order address does not match${NC}"
        exit 1
    fi
fi

# Test 5: Create Order with Custom Address
echo -e "\n${YELLOW}Test 5: Create Order with Custom Address${NC}"
CREATE_ORDER_CUSTOM_RESPONSE=$(api_call POST \
    "$ORDER_SERVICE_URL/v1/orders" \
    "{
        \"user_id\": \"$TEST_CUSTOMER_ID\",
        \"items\": [
            {
                \"product_id\": \"$TEST_PRODUCT_ID\",
                \"product_sku\": \"SKU-001\",
                \"quantity\": 1
            }
        ],
        \"shipping_address\": {
            \"type\": \"ADDRESS_TYPE_SHIPPING\",
            \"first_name\": \"Guest\",
            \"last_name\": \"User\",
            \"address_line_1\": \"789 Guest St\",
            \"city\": \"Los Angeles\",
            \"state_province\": \"CA\",
            \"postal_code\": \"90001\",
            \"country_code\": \"US\"
        },
        \"payment_method\": \"credit_card\"
    }" \
    "$AUTH_TOKEN")

ORDER_ID_CUSTOM=$(echo "$CREATE_ORDER_CUSTOM_RESPONSE" | jq -r '.order.id // empty')

if [ -z "$ORDER_ID_CUSTOM" ] || [ "$ORDER_ID_CUSTOM" == "null" ]; then
    echo -e "${RED}✗ FAIL: Could not create order with custom address${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASS: Order created with custom address${NC}"
fi

# Test 6: Verify Address Snapshot (Update customer address, verify order unchanged)
echo -e "\n${YELLOW}Test 6: Verify Address Snapshot${NC}"
UPDATE_ADDRESS_RESPONSE=$(api_call PUT \
    "$CUSTOMER_SERVICE_URL/v1/customers/$TEST_CUSTOMER_ID/addresses/$ADDRESS_ID" \
    '{
        "address_line_1": "UPDATED ADDRESS 999"
    }' \
    "$AUTH_TOKEN")

# Get order again and verify address unchanged
GET_ORDER_AGAIN_RESPONSE=$(api_call GET \
    "$ORDER_SERVICE_URL/v1/orders/$ORDER_ID" \
    "" \
    "$AUTH_TOKEN")

ORDER_ADDRESS_LINE1=$(echo "$GET_ORDER_AGAIN_RESPONSE" | jq -r '.order.shipping_address.address_line_1 // empty')

if [ "$ORDER_ADDRESS_LINE1" == "123 Main St" ]; then
    echo -e "${GREEN}✓ PASS: Order address snapshot unchanged after customer address update${NC}"
else
    echo -e "${RED}✗ FAIL: Order address changed (should be snapshot)${NC}"
    echo "Expected: 123 Main St, Got: $ORDER_ADDRESS_LINE1"
    exit 1
fi

echo -e "\n${GREEN}=== All Integration Tests Passed! ===${NC}"

