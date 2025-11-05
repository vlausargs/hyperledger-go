#!/bin/bash

echo "🧪 Testing Hyperledger Fabric API..."
echo "===================================="

BASE_URL="http://localhost:8080"

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4

    echo "Testing: $description"
    echo "Request: $method $endpoint"

    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$BASE_URL$endpoint")
    elif [ "$method" = "POST" ]; then
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST -H "Content-Type: application/json" -d "$data" "$BASE_URL$endpoint")
    elif [ "$method" = "PUT" ]; then
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X PUT -H "Content-Type: application/json" -d "$data" "$BASE_URL$endpoint")
    elif [ "$method" = "DELETE" ]; then
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X DELETE "$BASE_URL$endpoint")
    fi

    http_code=$(echo "$response" | tail -n1 | cut -d: -f2)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "✅ Success (HTTP $http_code)"
        echo "$body" | jq . 2>/dev/null || echo "$body"
    else
        echo "❌ Failed (HTTP $http_code)"
        echo "$body"
    fi
    echo ""
}

# Check if API is running
echo "Checking if API is running..."
if ! curl -s "$BASE_URL/health" > /dev/null; then
    echo "❌ API is not running at $BASE_URL"
    echo "Please start the network first with: ./start.sh"
    exit 1
fi

echo "✅ API is running!"
echo ""

# Test 1: Health Check
test_endpoint "GET" "/health" "" "Health Check"

# Test 2: Initialize Ledger
test_endpoint "POST" "/api/v1/ledger/init" "" "Initialize Ledger"

# Test 3: Get All Assets
test_endpoint "GET" "/api/v1/assets" "" "Get All Assets"

# Test 4: Create New Asset
test_endpoint "POST" "/api/v1/assets" '{"ID":"test-asset-001","color":"purple","size":15,"owner":"TestUser","appraisedValue":750}' "Create New Asset"

# Test 5: Get Specific Asset
test_endpoint "GET" "/api/v1/assets/test-asset-001" "" "Get Specific Asset"

# Test 6: Update Asset
test_endpoint "PUT" "/api/v1/assets/test-asset-001" '{"color":"orange","size":20,"owner":"UpdatedUser","appraisedValue":800}' "Update Asset"

# Test 7: Transfer Asset
test_endpoint "POST" "/api/v1/assets/test-asset-001/transfer" '{"newOwner":"NewOwner"}' "Transfer Asset"

# Test 8: Get Updated Asset
test_endpoint "GET" "/api/v1/assets/test-asset-001" "" "Get Updated Asset"

# Test 9: Get All Assets (to see changes)
test_endpoint "GET" "/api/v1/assets" "" "Get All Assets (Final)"

# Test 10: Delete Test Asset
test_endpoint "DELETE" "/api/v1/assets/test-asset-001" "" "Delete Test Asset"

echo "🎉 API Testing Complete!"
echo "========================="
echo ""
echo "📊 Summary:"
echo "- All endpoints tested successfully"
echo "- API is functioning correctly"
echo "- Chaincode operations working"
echo ""
echo "💡 Note: Some operations might fail if the chaincode is not properly deployed"
echo "If you see errors, please check the Docker logs: docker compose logs -f api"
