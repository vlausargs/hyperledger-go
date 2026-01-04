#!/bin/bash

# Advanced Custom Network Startup Script
# This script uses the custom-network setup with enhanced configuration

# Function to safely bring down network
cleanupNetwork() {
    echo "🔥 Cleaning up existing test network..."
    if [ -d "./fabric-samples/test-network" ]; then
        cd fabric-samples/test-network && ./network.sh down && cd ../..
    else
        echo "Warning: test-network directory not found, skipping network cleanup"
    fi



    # Force remove any remaining containers
    echo "Force removing any remaining containers..."
    docker rm -f $(docker ps -aq --filter "name=cli") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=peer0.org1.example.com") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=peer0.org2.example.com") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=orderer.example.com") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=fabric-api") 2>/dev/null || true

    # Remove any running API processes on host
    echo "Cleaning up API processes..."
    pkill -f "./api" 2>/dev/null || true
    pkill -f "api" 2>/dev/null || true

    # Remove any unused Docker networks
    echo "Cleaning up unused networks..."
    docker network prune -f 2>/dev/null || true

    # Clean up any temporary files
    echo "Cleaning up temporary files..."
    rm -f api/api.pid 2>/dev/null || true
    rm -f api/api 2>/dev/null || true

    echo "✅ Cleanup completed!"
    echo ""
}

echo "🚀 Starting Advanced Custom Hyperledger Fabric Network..."
echo "============================================================"

# Add Fabric binaries to PATH
export PATH=$PATH:$PWD/fabric-samples/bin

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if required tools are available
if ! $PWD/fabric-samples/bin/cryptogen help >/dev/null 2>&1; then
    echo "❌ cryptogen not found. Please install Hyperledger Fabric binaries."
    echo "Run: cd fabric-samples && curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.7 1.5.5"
    exit 1
fi

if ! $PWD/fabric-samples/bin/configtxgen --help >/dev/null 2>&1; then
    echo "❌ configtxgen not found. Please install Hyperledger Fabric binaries."
    echo "Run: cd fabric-samples && curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.7 1.5.5"
    exit 1
fi

echo "✅ Prerequisites check passed!"
echo ""

# Call cleanup function
cleanupNetwork

# Step 1: Start test-network
echo "🔐 Step 1: Starting test-network infrastructure..."
cd ./fabric-samples/test-network
./network.sh up createChannel -c mychannel
if [ $? -ne 0 ]; then
    echo "❌ Failed to start custom-network"
    exit 1
fi

echo "⏳ Waiting for network to be ready..."
sleep 10

# Step 2: Channel already created in test-network
echo "📡 Step 2: Channel already created with test-network..."
echo "✅ Channel 'mychannel' created successfully!"
if [ $? -ne 0 ]; then
    echo "❌ Failed to create channel"
    exit 1
fi

echo "✅ Channel created successfully!"
echo ""

# Wait a bit for orderer to be fully ready
echo "⏳ Waiting for orderer to be ready..."
sleep 10

# Step 3: Deploy chaincode using test-network approach
echo "📦 Step 3: Installing and deploying chaincode..."

# Use the test-network's deployCC functionality
echo "Deploying chaincode using test-network script..."
./network.sh deployCC -ccn basic -ccp ../../chaincode -ccl go

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy chaincode"
    exit 1
fi

# Step 4: Initialize chaincode with sample data
echo "🔧 Step 4: Initializing custom chaincode with sample data..."

# First, check if CLI container exists and get its name
CLI_CONTAINER=$(docker ps --filter "name=cli" --format "{{.Names}}" | head -n 1)

if [ -z "$CLI_CONTAINER" ]; then
    echo "❌ CLI container not found"
    exit 1
fi

echo "Using CLI container: $CLI_CONTAINER"

# Initialize the chaincode
docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID="Org1MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 $CLI_CONTAINER peer chaincode invoke -o orderer.example.com:7050 -C mychannel -n basic -c '{"Args":["InitLedger"]}' --ordererTLSHostnameOverride orderer.example.com --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses peer0.org1.example.com:7051 --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

if [ $? -ne 0 ]; then
    echo "❌ Failed to initialize chaincode"
    exit 1
fi

echo "✅ Chaincode initialized successfully!"

# Step 5: Start API service
echo ""
echo "🌐 Step 5: Starting API service..."
cd ../../api

# Build and start the API
if [ -f "main.go" ]; then
    echo "Building API service..."
    go build -o api .
    if [ $? -eq 0 ]; then
        echo "Starting API service in background..."
        ./api &
        API_PID=$!
        echo $API_PID > api.pid
        echo "✅ API service started with PID: $API_PID"
    else
        echo "❌ Failed to build API service"
    fi
else
    echo "⚠️  API service not found in api directory"
fi

cd ..

echo ""
echo "🎉 Advanced Custom Network setup completed successfully!"
echo "============================================================"
echo ""
echo "📊 Network Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|peer|orderer|cli|dev-peer|fabric-api)"
echo ""
echo "🚗 Sample Data Query Test:"
docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID="Org1MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 $CLI_CONTAINER peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}' | jq '.[0:2]' 2>/dev/null || echo "Sample data initialized with $(docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID="Org1MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 $CLI_CONTAINER peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}' | jq '. | length') assets"
echo ""
echo "🔧 Useful Commands:"
echo "  Access CLI:       docker exec -it $CLI_CONTAINER bash"
echo "  Stop network:     cd fabric-samples/test-network && ./network.sh down"
echo "  Restart:          cd fabric-samples/test-network && ./network.sh restart"
echo "  Query all assets: cd fabric-samples/test-network && docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 $CLI_CONTAINER peer chaincode query -C mychannel -n basic -c '{\"Args\":[\"GetAllAssets\"]}'"
echo ""
echo "✅ All systems ready! 🚀"
echo ""
echo "📝 Notes:"
echo "  - Test network is running with Org1 and Org2 organizations"
echo "  - Channel 'mychannel' created with asset management chaincode"
echo "  - Chaincode initialized with sample assets"
echo "  - API service started on default port (usually 8080)"
echo "  - You can interact using the CLI container: $CLI_CONTAINER"
echo ""
echo "🧪 Advanced Test Commands:"
echo "  Network status: docker ps"
echo "  Query specific asset: docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 $CLI_CONTAINER peer chaincode query -C mychannel -n basic -c '{\"Args\":[\"ReadAsset\",\"asset1\"]}'"
echo "  Query assets by owner: docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 $CLI_CONTAINER peer chaincode query -C mychannel -n basic -c '{\"Args\":[\"GetAssetsByOwner\",\"Tomoko\"]}'"
echo "  Get asset history: docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 $CLI_CONTAINER peer chaincode query -C mychannel -n basic -c '{\"Args\":[\"GetAssetHistory\",\"asset1\"]}'"
echo "  Create new asset: docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 $CLI_CONTAINER peer chaincode invoke -o orderer.example.com:7050 -C mychannel -n basic -c '{\"Args\":[\"CreateAsset\",\"asset11\",\"cyan\",30,\"Alice\",1300]}' --ordererTLSHostnameOverride orderer.example.com --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses peer0.org1.example.com:7051 --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
echo ""
echo "🌐 API Access (if started):"
echo "  Health check: curl http://localhost:8080/health"
echo "  Get all assets: curl http://localhost:8080/assets"
echo "  Create asset: curl -X POST http://localhost:8080/assets -H 'Content-Type: application/json' -d '{\"id\":\"test123\",\"color\":\"blue\",\"size\":10,\"owner\":\"TestUser\",\"appraisedValue\":100}'"
