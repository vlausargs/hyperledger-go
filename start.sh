#!/bin/bash

# Simple working start script using test-network approach
# This will use proven working test-network setup + add our Go API

# Function to safely bring down network
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
    docker rm -f $(docker ps -aq --filter "name=cli") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=peer0.org1.example.com") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=peer0.org2.example.com") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=peer1.org1.example.com") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=peer1.org2.example.com") 2>/dev/null || true
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

    cd ../..
    echo "✅ Cleanup completed!"
    echo ""
}

echo "🚀 Starting Hyperledger Fabric Network (Working Version)..."
echo "================================================="

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

# Step 1: Start test-network (Fabric infrastructure)
echo "🔐 Step 1: Starting test-network..."
cd fabric-samples/test-network
./network.sh up
if [ $? -ne 0 ]; then
    echo "❌ Failed to start test-network"
    exit 1
fi

echo "⏳ Waiting for network to be ready..."
sleep 10

# Step 2: Create channel using test-network scripts
echo "📡 Step 2: Creating channel..."
./network.sh createChannel
if [ $? -ne 0 ]; then
    echo "❌ Failed to create channel"
    exit 1
fi

echo "✅ Channel created successfully!"
echo ""

# Step 3: Install chaincode using test-network approach
echo "📦 Step 3: Installing and deploying chaincode..."

# Use the test-network's deployCC script which handles all the environment variables properly
echo "Deploying custom chaincode using test-network script..."
./network.sh deployCC -ccn custom-chaincode -ccp ../../chaincode -ccl go

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy chaincode"
    exit 1
fi

# Step 4: Initialize chaincode with sample data
echo "🔧 Step 4: Initializing custom chaincode with sample data..."
docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID="Org1MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 cli peer chaincode invoke -C mychannel -n custom-chaincode -c '{"Args":["InitLedger"]}' --orderer orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses peer0.org1.example.com:7051 --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

if [ $? -ne 0 ]; then
    echo "❌ Failed to initialize chaincode"
    exit 1
fi

echo "✅ Chaincode initialized successfully!"

# Step 5: Start API service
echo ""
echo "🎉 Network setup completed successfully!"
echo "============================================================"
echo ""
echo "📊 Network Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|peer|orderer|cli|dev-peer)"
echo ""
echo "🚗 Sample Data Query Test:"
docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID="Org1MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 cli peer chaincode query -C mychannel -n custom-chaincode -c '{"Args":["GetAllAssets"]}' | jq '.[0:2]' 2>/dev/null || echo "Sample data initialized with $(docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID="Org1MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 cli peer chaincode query -C mychannel -n custom-chaincode -c '{"Args":["GetAllAssets"]}' | jq '. | length') assets"
echo ""
echo "🔧 Useful Commands:"
echo "  Access CLI:       docker exec -it cli bash"
echo "  Stop network:     cd fabric-samples/test-network && ./network.sh down"
echo "  Restart:          cd fabric-samples/test-network && docker compose restart"
echo "  Query all assets: cd fabric-samples/test-network && docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 cli peer chaincode query -C mychannel -n custom-chaincode -c '{\"Args\":[\"GetAllAssets\"]}'"
echo ""
echo "✅ All systems ready! 🚀"
echo ""
echo "📝 Notes:"
echo "  - Network is running with custom asset management chaincode deployed"
echo "  - Chaincode initialized with 10 sample assets with enhanced features"
echo "  - You can interact using the CLI container"
echo "  - To start the API manually: cd api && go build -o api . && ./api &"
echo ""
echo "🧪 Test Commands:"
echo "  Network status: docker ps"
echo "  Query specific asset: docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 cli peer chaincode query -C mychannel -n custom-chaincode -c '{\"Args\":[\"ReadAsset\",\"asset1\"]}'"
echo "  Query assets by owner: docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 cli peer chaincode query -C mychannel -n custom-chaincode -c '{\"Args\":[\"GetAssetsByOwner\",\"Tomoko\"]}'"
echo "  Get asset history: docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 cli peer chaincode query -C mychannel -n custom-chaincode -c '{\"Args\":[\"GetAssetHistory\",\"asset1\"]}'"
echo "  Create new asset: docker exec -e CORE_PEER_TLS_ENABLED=true -e CORE_PEER_LOCALMSPID='Org1MSP' -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 cli peer chaincode invoke -C mychannel -n custom-chaincode -c '{\"Args\":[\"CreateAsset\",\"asset11\",\"cyan\",30,\"Alice\",1300]}' --orderer orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses peer0.org1.example.com:7051 --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
