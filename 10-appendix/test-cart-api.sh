#!/bin/bash

# Test Cart API via Gateway
# This script tests cart endpoints to verify routing is working correctly

set -e

GATEWAY_URL="${GATEWAY_URL:-https://api.tanhdev.com}"
SESSION_ID="session_$(date +%s)_test"
GUEST_TOKEN="guest_$(date +%s)_test"

echo "================================================"
echo "Testing Cart API via Gateway"
echo "================================================"
echo "Gateway URL: $GATEWAY_URL"
echo "Session ID: $SESSION_ID"
echo "Guest Token: $GUEST_TOKEN"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Get Cart (should return 404 or empty cart for new session)
echo -e "${YELLOW}Test 1: GET /api/v1/cart (Get Cart)${NC}"
echo "----------------------------------------"
HTTP_CODE=$(curl -s -o /tmp/cart-response.json -w "%{http_code}" \
  -X GET "${GATEWAY_URL}/api/v1/cart?session_id=${SESSION_ID}&guest_token=${GUEST_TOKEN}" \
  -H "accept: application/json" \
  -H "x-session-id: ${SESSION_ID}" \
  -H "x-guest-token: ${GUEST_TOKEN}")

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
cat /tmp/cart-response.json | jq '.' 2>/dev/null || cat /tmp/cart-response.json
echo ""

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
  echo -e "${GREEN}✓ Test 1 PASSED${NC}"
  echo "  - 200: Cart found (may be empty)"
  echo "  - 404: Cart not found (will be created on first add)"
else
  echo -e "${RED}✗ Test 1 FAILED${NC}"
  echo "  Expected: 200 or 404"
  echo "  Got: $HTTP_CODE"
fi
echo ""

# Test 2: Add Item to Cart
echo -e "${YELLOW}Test 2: POST /api/v1/cart/items (Add Item)${NC}"
echo "----------------------------------------"
HTTP_CODE=$(curl -s -o /tmp/cart-add-response.json -w "%{http_code}" \
  -X POST "${GATEWAY_URL}/api/v1/cart/items" \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  -H "x-session-id: ${SESSION_ID}" \
  -H "x-guest-token: ${GUEST_TOKEN}" \
  -d '{
    "product_id": "test-product-001",
    "quantity": 2,
    "warehouse_id": "warehouse-001"
  }')

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
cat /tmp/cart-add-response.json | jq '.' 2>/dev/null || cat /tmp/cart-add-response.json
echo ""

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✓ Test 2 PASSED${NC}"
elif [ "$HTTP_CODE" = "404" ]; then
  echo -e "${YELLOW}⚠ Test 2 WARNING${NC}"
  echo "  404: Product or warehouse not found"
else
  echo -e "${RED}✗ Test 2 FAILED${NC}"
  echo "  Expected: 200"
  echo "  Got: $HTTP_CODE"
fi
echo ""

# Test 3: Get Cart Again (should have items now if add succeeded)
echo -e "${YELLOW}Test 3: GET /api/v1/cart (Verify Item Added)${NC}"
echo "----------------------------------------"
HTTP_CODE=$(curl -s -o /tmp/cart-verify-response.json -w "%{http_code}" \
  -X GET "${GATEWAY_URL}/api/v1/cart?session_id=${SESSION_ID}&guest_token=${GUEST_TOKEN}" \
  -H "accept: application/json" \
  -H "x-session-id: ${SESSION_ID}" \
  -H "x-guest-token: ${GUEST_TOKEN}")

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
cat /tmp/cart-verify-response.json | jq '.' 2>/dev/null || cat /tmp/cart-verify-response.json
echo ""

if [ "$HTTP_CODE" = "200" ]; then
  ITEM_COUNT=$(cat /tmp/cart-verify-response.json | jq '.items | length' 2>/dev/null || echo "0")
  echo -e "${GREEN}✓ Test 3 PASSED${NC}"
  echo "  Items in cart: $ITEM_COUNT"
else
  echo -e "${RED}✗ Test 3 FAILED${NC}"
  echo "  Expected: 200"
  echo "  Got: $HTTP_CODE"
fi
echo ""

# Test 4: Test with your actual session IDs from frontend
echo -e "${YELLOW}Test 4: Test with Frontend Session IDs${NC}"
echo "----------------------------------------"
FRONTEND_SESSION="session_1769598824224_zkeohw9gj"
FRONTEND_GUEST="guest_1769598824224_locd8ff0x"
FRONTEND_USER_ID="574be5a3-ac40-4161-ab12-8f89c37ab5c3"

echo "Using frontend credentials:"
echo "  Session ID: $FRONTEND_SESSION"
echo "  Guest Token: $FRONTEND_GUEST"
echo "  User ID: $FRONTEND_USER_ID"
echo ""

HTTP_CODE=$(curl -s -o /tmp/cart-frontend-response.json -w "%{http_code}" \
  -X GET "${GATEWAY_URL}/api/v1/cart?session_id=${FRONTEND_SESSION}&guest_token=${FRONTEND_GUEST}" \
  -H "accept: application/json" \
  -H "x-session-id: ${FRONTEND_SESSION}" \
  -H "x-guest-token: ${FRONTEND_GUEST}" \
  -H "x-user-id: ${FRONTEND_USER_ID}")

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
cat /tmp/cart-frontend-response.json | jq '.' 2>/dev/null || cat /tmp/cart-frontend-response.json
echo ""

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
  echo -e "${GREEN}✓ Test 4 PASSED${NC}"
else
  echo -e "${RED}✗ Test 4 FAILED${NC}"
  echo "  Expected: 200 or 404"
  echo "  Got: $HTTP_CODE"
fi
echo ""

# Summary
echo "================================================"
echo "Test Summary"
echo "================================================"
echo "All tests completed. Review results above."
echo ""
echo "Common issues:"
echo "  - 404: Normal for new carts (will be created on first add)"
echo "  - 401: Authentication issue or invalid session"
echo "  - 502/504: Gateway can't reach Checkout Service"
echo "  - 500: Internal server error in Checkout Service"
echo ""
echo "Next steps:"
echo "  1. Check Gateway logs: kubectl logs -n default deployment/gateway"
echo "  2. Check Checkout logs: kubectl logs -n default deployment/checkout"
echo "  3. Verify service is running: kubectl get pods -n default | grep checkout"
echo ""
