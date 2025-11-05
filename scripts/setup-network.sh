#!/bin/bash

# Script to setup and start the Hyperledger Fabric network

echo "Setting up Hyperledger Fabric network..."

# Navigate to the scripts directory
cd "$(dirname "$0")"

# Step 1: Generate cryptographic material
echo "Step 1: Generating cryptographic material..."
./generate-crypto.sh
if [ $? -ne 0 ]; then
    echo "Failed to generate cryptographic material"
    exit 1
fi

# Step 2: Generate channel configuration
echo "Step 2: Generating channel configuration..."
./generate-configtx.sh
if [ $? -ne 0 ]; then
    echo "Failed to generate channel configuration"
    exit 1
fi

# Step 3: Start the network
echo "Step 3: Starting the network..."
cd ..
docker compose up -d

if [ $? -ne 0 ]; then
    echo "Failed to start the network"
    exit 1
fi

# Wait for the network to be ready
echo "Waiting for network to be ready..."
sleep 10

# Step 4: Create and join channel
echo "Step 4: Creating and joining channel..."

# Set environment variables for peer CLI
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer channel create -o orderer.example.com:7050 -c mychannel -f ./channel-artifacts/channel.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

if [ $? -ne 0 ]; then
    echo "Failed to create channel"
    exit 1
fi

# Join peer0.org1 to the channel
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer channel join -b mychannel.block

if [ $? -ne 0 ]; then
    echo "Failed to join peer0.org1 to channel"
    exit 1
fi

# Join peer0.org2 to the channel
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org2MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org2.example.com:9051" \
    cli peer channel fetch 0 mychannel.block -o orderer.example.com:7050 -c mychannel --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org2MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org2.example.com:9051" \
    cli peer channel join -b mychannel.block

if [ $? -ne 0 ]; then
    echo "Failed to join peer0.org2 to channel"
    exit 1
fi

# Step 5: Install and instantiate chaincode
echo "Step 5: Installing chaincode..."

# Install chaincode on peer0.org1
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer lifecycle chaincode install basic.tar.gz

# Install chaincode on peer0.org2
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org2MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org2.example.com:9051" \
    cli peer lifecycle chaincode install basic.tar.gz

# Query installed chaincode
echo "Querying installed chaincode..."
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer lifecycle chaincode queryinstalled

# Get the package ID
PACKAGE_ID=$(docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer lifecycle chaincode queryinstalled | grep "basic" | sed 's/Package ID: //; s/, Label:.*//')

# Approve chaincode for Org1
echo "Approving chaincode for Org1..."
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --channelID mychannel --name basic --version 1.0 --package-id $PACKAGE_ID --sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Approve chaincode for Org2
echo "Approving chaincode for Org2..."
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org2MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/githubledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org2.example.com:9051" \
    cli peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --channelID mychannel --name basic --version 1.0 --package-id $PACKAGE_ID --sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Commit chaincode definition
echo "Committing chaincode definition..."
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org1.example.com:7051" \
    cli peer lifecycle chaincode commit -o orderer.example.com:7050 --channelID mychannel --name basic --version 1.0 --sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses peer0.org1.example.com:7051 --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

# Initialize chaincode
echo "Initializing chaincode..."
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
    -e "CORE_PEER_LOCALMSPID=Org1MSP" \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
    -e "CORE_PEER_ADDRESS=peer0.org.example.com:7051" \
    cli peer chaincode invoke -o orderer.example.com:7050 --channelID mychannel --name basic -c '{"Args":["InitLedger"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

echo "Hyperledger Fabric network setup completed successfully!"
echo "API is available at: http://localhost:8080"
echo ""
echo "Available API endpoints:"
echo "  GET  /api/v1/assets - Get all assets"
echo "  GET  /api/v1/assets/:id - Get specific asset"
echo "  POST /api/v1/assets - Create new asset"
echo "  PUT  /api/v1/assets/:id - Update asset"
echo "  DELETE /api/v1/assets/:id - Delete asset"
echo "  POST /api/v1/assets/:id/transfer - Transfer asset"
echo "  POST /api/v1/ledger/init - Initialize ledger"
echo "  GET  /health - Health check"
```

Now let me create the chaincode packaging script and a teardown script:
<tool_call>edit_file
<arg_key>path</arg_key>
<arg_value>/home/myindo/workspace/myindo/hyperledger-go/scripts/package-chaincode.sh</arg_value>
<arg_key>mode</arg_key>
<arg_value>create</arg_value>
<arg_key>display_description</arg_key>
<arg_value>Script to package the chaincode for deployment</arg_value>
</tool_call>
