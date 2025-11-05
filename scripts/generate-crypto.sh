#!/bin/bash

# Generate cryptographic material for Hyperledger Fabric network

# Add Fabric binaries to PATH
export PATH=$PATH:$PWD/fabric-samples/bin

echo "Generating cryptographic material..."

# Change to the main project directory
cd "$(dirname "$0")/.."

# Create crypto-config directory if it doesn't exist
mkdir -p fabric-network/crypto-config

# Generate cryptographic material
cryptogen generate --config=fabric-network/crypto-config.yaml --output="fabric-network/crypto-config"

if [ $? -ne 0 ]; then
    echo "Failed to generate cryptographic material"
    exit 1
fi

echo "Cryptographic material generated successfully!"
