#!/bin/bash

# Script to package the chaincode for deployment

echo "Packaging chaincode..."

# Navigate to the chaincode directory
cd "$(dirname "$0")/../chaincode"

# Create the chaincode package
tar -czf basic.tar.gz chaincode.go go.mod go.sum

if [ $? -ne 0 ]; then
    echo "Failed to package chaincode"
    exit 1
fi

# Copy the package to the scripts directory
cp basic.tar.gz ../scripts/

echo "Chaincode packaged successfully!"
