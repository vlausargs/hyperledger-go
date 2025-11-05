#!/bin/bash

# Generate genesis block and channel configuration for Hyperledger Fabric network

# Add Fabric binaries to PATH
export PATH=$PATH:$PWD/fabric-samples/bin

echo "Generating channel configuration..."

# Change to the main project directory
cd "$(dirname "$0")/.."

# Create channel-artifacts directory if it doesn't exist
mkdir -p fabric-network/channel-artifacts

# Set FABRIC_CFG_PATH to the configtx directory
export FABRIC_CFG_PATH="fabric-network/configtx"



# Generate genesis block
echo "Generating genesis block..."
configtxgen -profile TwoOrgsOrdererGenesis -channelID system-channel -outputBlock fabric-network/channel-artifacts/genesis.block

if [ $? -ne 0 ]; then
    echo "Failed to generate genesis block"
    exit 1
fi

# Generate channel configuration transaction
echo "Generating channel configuration transaction..."
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx fabric-network/channel-artifacts/channel.tx -channelID mychannel

if [ $? -ne 0 ]; then
    echo "Failed to generate channel configuration transaction"
    exit 1
fi

# Generate anchor peer update for Org1
echo "Generating anchor peer update for Org1..."
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate fabric-network/channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP

if [ $? -ne 0 ]; then
    echo "Failed to generate anchor peer update for Org1"
    exit 1
fi

# Generate anchor peer update for Org2
echo "Generating anchor peer update for Org2..."
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate fabric-network/channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP

if [ $? -ne 0 ]; then
    echo "Failed to generate anchor peer update for Org2"
    exit 1
fi

echo "Channel configuration generated successfully!"
