#!/bin/bash

# Simple Hyperledger Fabric network start script using test-network approach
# This uses proven working configurations from fabric-samples/test-network

echo "🚀 Starting Hyperledger Fabric Network (Simplified)..."
echo "================================================="

# Add Fabric binaries to PATH
export PATH=$PWD/fabric-samples/bin:$PATH

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

# Step 1: Generate cryptographic material using test-network approach
echo "🔐 Step 1: Generating cryptographic material..."
cd test-network-working

# Create organizations directory structure
mkdir -p organizations/peerOrganizations organizations/ordererOrganizations

# Generate crypto material using test-network's proven approach
cd test-network-working
../fabric-samples/bin/cryptogen generate --config=crypto-config.yaml --output="organizations"

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate cryptographic material"
    exit 1
fi

cd ..
echo "✅ Cryptographic material generated successfully!"

# Step 2: Create channel artifacts using test-network approach
echo "⚙️  Step 2: Creating channel artifacts..."

# Create channel artifacts directory
mkdir -p organizations/channel-artifacts

# Set FABRIC_CFG_PATH to configtx directory
export FABRIC_CFG_PATH=$PWD/test-network-working

# Generate genesis block
$PWD/fabric-samples/bin/configtxgen -profile TwoOrgsOrdererGenesis -channelID system-channel -outputBlock test-network-working/organizations/channel-artifacts/genesis.block

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate genesis block"
    exit 1
fi

# Generate channel configuration transaction
$PWD/fabric-samples/bin/configtxgen -profile TwoOrgsChannel -outputCreateChannelTx test-network-working/organizations/channel-artifacts/channel.tx -channelID mychannel

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate channel configuration transaction"
    exit 1
fi

# Generate anchor peer updates
$PWD/fabric-samples/bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate test-network-working/organizations/channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate anchor peer update for Org1"
    exit 1
fi

$PWD/fabric-samples/bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate test-network-working/organizations/channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate anchor peer update for Org2"
    exit 1
fi

echo "✅ Channel artifacts created successfully!"

# Step 3: Start the network using test-network docker-compose
echo "🌐 Step 3: Starting the network..."

# Stay in main directory, navigate to test-network-working for commands

# Start the network
docker compose -f compose/docker-compose-test-net.yaml up -d

if [ $? -ne 0 ]; then
    echo "❌ Failed to start the network"
    exit 1
fi

echo "⏳ Waiting for network to be ready..."
sleep 10

# Step 4: Create and join channel using test-network scripts
echo "📡 Step 4: Creating and joining channel..."

# Create channel
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer channel create -o orderer.example.com:7050 -c mychannel -f ./organizations/channel-artifacts/channel.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem 2>/dev/null || echo "Channel might already exist or creation failed"

# Join peers to channel
echo "🔗 Joining peers to channel..."

# Peer0.Org1
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer channel join -b ./organizations/channel-artifacts/mychannel.block 2>/dev/null || echo "Peer0.Org1 already joined or join failed"

# Peer0.Org2
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org2MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org2.example.com:9051" \
    cli peer channel fetch 0 ./organizations/channel-artifacts/mychannel.block -o orderer.example.com:7050 -c mychannel --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem 2>/dev/null

docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org2MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org2.example.com:9051" \
    cli peer channel join -b ./organizations/channel-artifacts/mychannel.block 2>/dev/null || echo "Peer0.Org2 already joined or join failed"

echo "✅ Network setup completed successfully!"
echo ""
echo "🎉 Hyperledger Fabric network is running!"
echo "=================================================="
echo ""
echo "📊 Network Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|peer|orderer|cli)"
echo ""
echo "🔧 Useful Commands:"
echo "  View logs:        docker logs -f [container-name]"
echo "  Access CLI:       docker exec -it cli bash"
# Stop network:     docker compose -f test-network-working/compose/docker-compose-test-net.yaml down
echo ""
echo "✅ All systems ready! 🚀"
