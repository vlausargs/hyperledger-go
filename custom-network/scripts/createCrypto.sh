#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script generates the cryptographic material for the Hyperledger Fabric network
# using the cryptogen tool based on the crypto-config.yaml file

. scripts/utils.sh

# Function to generate crypto material using cryptogen
generateCrypto() {
  if [ ! -f "../bin/cryptogen" ]; then
    fatalln "cryptogen binary not found in ../bin directory"
  fi

  infoln "Generating cryptographic material using cryptogen..."

  # Remove existing crypto material
  if [ -d "organizations" ]; then
    rm -rf organizations
  fi

  # Generate crypto material
  set -x
  ../bin/cryptogen generate --config=configtx/crypto-config.yaml --output="organizations"
  res=$?
  { set +x; } 2>/dev/null

  if [ $res -ne 0 ]; then
    fatalln "Failed to generate cryptographic material"
  fi

  successln "Cryptographic material generated successfully"
}

# Function to create the Orderer genesis block
createGenesisBlock() {
  if [ ! -f "../bin/configtxgen" ]; then
    fatalln "configtxgen binary not found in ../bin directory"
  fi

  infoln "Creating Orderer genesis block..."

  # Create system-genesis-block directory if it doesn't exist
  mkdir -p system-genesis-block

  set -x
  ../bin/configtxgen -profile MyindoNetworkGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
  res=$?
  { set +x; } 2>/dev/null

  if [ $res -ne 0 ]; then
    fatalln "Failed to generate orderer genesis block"
  fi

  successln "Orderer genesis block created successfully"
}

# Function to create channel artifacts
createChannelArtifacts() {
  if [ ! -f "../bin/configtxgen" ]; then
    fatalln "configtxgen binary not found in ../bin directory"
  fi

  infoln "Creating channel artifacts..."

  # Create channel-artifacts directory if it doesn't exist
  mkdir -p channel-artifacts

  # Generate channel configuration transaction
  set -x
  ../bin/configtxgen -profile MyindoNetworkGenesis -channelID myindochannel -outputCreateChannelTx ./channel-artifacts/myindochannel.tx
  res=$?
  { set +x; } 2>/dev/null

  if [ $res -ne 0 ]; then
    fatalln "Failed to generate channel configuration transaction"
  fi

  # Generate anchor peer updates for each organization
  ../bin/configtxgen -profile MyindoNetworkGenesis -channelID myindochannel -outputAnchorPeersUpdate ./channel-artifacts/BankOrgMSPanchors.tx -asOrg BankOrgMSP
  res=$?
  { set +x; } 2>/dev/null

  if [ $res -ne 0 ]; then
    fatalln "Failed to generate anchor peer update for BankOrgMSP"
  fi

  ../bin/configtxgen -profile MyindoNetworkGenesis -channelID myindochannel -outputAnchorPeersUpdate ./channel-artifacts/InsuranceOrgMSPanchors.tx -asOrg InsuranceOrgMSP
  res=$?
  { set +x; } 2>/dev/null

  if [ $res -ne 0 ]; then
    fatalln "Failed to generate anchor peer update for InsuranceOrgMSP"
  fi

  ../bin/configtxgen -profile MyindoNetworkGenesis -channelID myindochannel -outputAnchorPeersUpdate ./channel-artifacts/HealthcareOrgMSPanchors.tx -asOrg HealthcareOrgMSP
  res=$?
  { set +x; } 2>/dev/null

  if [ $res -ne 0 ]; then
    fatalln "Failed to generate anchor peer update for HealthcareOrgMSP"
  fi

  successln "Channel artifacts created successfully"
}

# Function to verify generated artifacts
verifyArtifacts() {
  infoln "Verifying generated artifacts..."

  # Check if organizations directory exists and has expected structure
  if [ ! -d "organizations/peerOrganizations" ]; then
    fatalln "Peer organizations directory not found"
  fi

  if [ ! -d "organizations/ordererOrganizations" ]; then
    fatalln "Orderer organizations directory not found"
  fi

  # Check if genesis block exists
  if [ ! -f "system-genesis-block/genesis.block" ]; then
    fatalln "Orderer genesis block not found"
  fi

  # Check if channel artifacts exist
  if [ ! -f "channel-artifacts/myindochannel.tx" ]; then
    fatalln "Channel configuration transaction not found"
  fi

  successln "All artifacts verified successfully"
}

# Function to display tree structure of generated artifacts
showTree() {
  infoln "Generated artifacts tree structure:"
  if command -v tree >/dev/null 2>&1; then
    tree -L 3 organizations/ system-genesis-block/ channel-artifacts/
  else
    echo "organizations/"
    find organizations/ -type f | head -20
    echo ""
    echo "system-genesis-block/"
    ls -la system-genesis-block/
    echo ""
    echo "channel-artifacts/"
    ls -la channel-artifacts/
  fi
}

# Main execution
infoln "Starting crypto material generation process..."

# Generate cryptographic material
generateCrypto

# Create orderer genesis block
createGenesisBlock

# Create channel artifacts
createChannelArtifacts

# Verify generated artifacts
verifyArtifacts

# Show tree structure
showTree

successln "Crypto material generation completed successfully!"
echo ""
echo "You can now start the network using: ./network.sh up"
