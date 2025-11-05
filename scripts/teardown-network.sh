#!/bin/bash

# Script to stop and clean up the Hyperledger Fabric network

echo "Tearing down Hyperledger Fabric network..."

# Navigate to the project root
cd "$(dirname "$0")/.."

# Stop and remove containers
echo "Stopping and removing containers..."
docker compose down

# Remove chaincode packages
echo "Cleaning up chaincode packages..."
rm -f scripts/basic.tar.gz
rm -f chaincode/basic.tar.gz

# Remove volumes (optional - uncomment if you want to remove all data)
# echo "Removing volumes..."
# docker volume prune -f

# Clean up generated artifacts
echo "Cleaning up generated artifacts..."
rm -rf fabric-network/crypto-config
rm -rf fabric-network/channel-artifacts

# Remove any leftover chaincode images
echo "Removing chaincode Docker images..."
docker rmi -f $(docker images -q "dev-*" 2>/dev/null) 2>/dev/null || true

# Remove stopped containers
echo "Removing stopped containers..."
docker container prune -f

# Remove unused networks
echo "Removing unused networks..."
docker network prune -f

echo "Network teardown completed successfully!"
