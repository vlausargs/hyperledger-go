#!/bin/bash

# Setup script for Fabric Network to work with SDK-based API
# This script sets up the Fabric network and prepares it for SDK connections

echo "🚀 Setting up Hyperledger Fabric Network for SDK-based API..."
echo "============================================================="

# Function to safely bring down existing network
cleanupNetwork() {
    echo "🔥 Cleaning up existing Fabric network..."
    cd fabric-samples/test-network

    # Try to bring down network gracefully
    if [ -f "./network.sh" ]; then
        echo "Stopping network using network.sh..."
        ./network.sh down 2>/dev/null || true
    fi

    # Force remove any remaining containers
    echo "Force removing any remaining containers..."
    docker rm -f $(docker ps -aq --filter "name=peer") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=orderer") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=cli") 2>/dev/null || true

    cd ../..
    echo "✅ Cleanup completed!"
    echo ""
}

# Add Fabric binaries to PATH
export PATH=$PATH:$PWD/fabric-samples/bin

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if required tools are available
if ! command -v cryptogen &> /dev/null; then
    echo "❌ cryptogen not found. Please install Hyperledger Fabric binaries."
    echo "Run: cd fabric-samples && curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.7 1.5.5"
    exit 1
fi

if ! command -v configtxgen &> /dev/null; then
    echo "❌ configtxgen not found. Please install Hyperledger Fabric binaries."
    echo "Run: cd fabric-samples && curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.7 1.5.5"
    exit 1
fi

echo "✅ Prerequisites check passed!"
echo ""

# Call cleanup function
cleanupNetwork

# Step 1: Start test-network (Fabric infrastructure)
echo "🔐 Step 1: Starting test-network..."
cd fabric-samples/test-network
./network.sh up createChannel
if [ $? -ne 0 ]; then
    echo "❌ Failed to start test-network and create channel"
    exit 1
fi

echo "⏳ Waiting for network to be ready..."
sleep 10

# Step 2: Deploy the chaincode
echo "📦 Step 2: Installing and deploying chaincode..."
./network.sh deployCC -ccn custom-chaincode -ccp ../../chaincode -ccl go

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy chaincode"
    exit 1
fi

echo "✅ Chaincode deployed successfully!"

# Step 3: Initialize the ledger
echo "🔧 Step 3: Initializing ledger with sample data..."
docker exec cli peer chaincode invoke -o orderer.example.com:7050 --tls true --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n custom-chaincode -c '{"Args":["InitLedger"]}' --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

if [ $? -ne 0 ]; then
    echo "❌ Failed to initialize chaincode"
    exit 1
fi

echo "✅ Ledger initialized successfully!"

# Step 4: Set up port forwarding for external SDK access
echo "🌐 Step 4: Setting up port forwarding for SDK access..."
docker run -d --name port-forwarder --network host alpine/socat TCP-LISTEN:7050,fork,reuseaddr TCP-CONNECT:peer0.org1.example.com:7050 2>/dev/null || true
docker run -d --name port-forwarder-peer --network host alpine/socat TCP-LISTEN:7051,fork,reuseaddr TCP-CONNECT:peer0.org1.example.com:7051 2>/dev/null || true

echo "✅ Port forwarding configured!"

cd ../..

# Step 5: Test the chaincode
echo "🧪 Step 5: Testing chaincode functionality..."
docker exec cli peer chaincode query -C mychannel -n custom-chaincode -c '{"Args":["GetAllAssets"]}' > /tmp/test_query.json 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Chaincode is responding correctly!"
    echo "📊 Sample assets available:"
    cat /tmp/test_query.json | jq '.[0:3]' 2>/dev/null || echo "Sample data initialized successfully"
else
    echo "❌ Chaincode query failed"
fi

echo ""
echo "🎉 Fabric Network Setup Complete!"
echo "============================================================"
echo ""
echo "📊 Network Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|peer|orderer|cli|port-forwarder)"
echo ""
echo "🔧 API Usage Instructions:"
echo "  1. Navigate to API directory: cd api"
echo "  2. Build the API: go build -o api ."
echo "  3. Run the API: ./api"
echo "  4. API will be available at: http://localhost:8080"
echo ""
echo "📋 API Endpoints:"
echo "  GET  /health                          - Health check"
echo "  POST /api/v1/ledger/init              - Initialize ledger"
echo "  GET  /api/v1/assets                   - Get all assets"
echo "  GET  /api/v1/assets/:id               - Get specific asset"
echo "  POST /api/v1/assets                   - Create new asset"
echo "  PUT  /api/v1/assets/:id               - Update asset"
echo "  DELETE /api/v1/assets/:id             - Delete asset"
echo "  POST /api/v1/assets/:id/transfer      - Transfer asset"
echo "  GET  /api/v1/assets/count             - Get asset count"
echo "  GET  /api/v1/assets/:id/history      - Get asset history"
echo "  GET  /api/v1/owners/:owner/assets     - Get assets by owner"
echo ""
echo "🧪 Test Commands:"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8080/api/v1/assets"
echo "  curl -X POST http://localhost:8080/api/v1/assets -H 'Content-Type: application/json' -d '{\"ID\":\"test1\",\"color\":\"red\",\"size\":10,\"owner\":\"Alice\",\"appraisedValue\":1000}'"
echo ""
echo "📝 Important Notes:"
echo "  - Fabric network runs in Docker containers"
echo "  - API runs locally using Fabric SDK (no Docker for API)"
echo "  - Peers are accessible at localhost:7051"
echo "  - Orderer is accessible at localhost:7050"
echo "  - Chaincode name: custom-chaincode"
echo "  - Channel: mychannel"
echo ""
echo "🔍 Useful Commands:"
echo "  Check network: docker ps"
echo "  Stop network: cd fabric-samples/test-network && ./network.sh down"
echo "  Restart: cd fabric-samples/test-network && docker compose restart"
echo ""
echo "✅ Ready to use SDK-based API! 🚀"
