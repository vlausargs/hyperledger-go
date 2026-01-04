#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script creates a channel and joins peers to the channel

CHANNEL_NAME=${1:-"myindochannel"}
CC_RUNTIME_LANGUAGE=${2:-"golang"}
VERSION="1.0"
DELAY="3"
MAX_RETRY="5"
VERBOSE="false"

. scripts/utils.sh

# Set the orderer CA
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/myindo.com/orderers/orderer.myindo.com/msp/tlscacerts/tlsca.myindo.com-cert.pem

# Create channel
createChannel() {
  setGlobals bank 7051

  # Poll in case the raft leader is not set yet
  local rc=1
  local COUNTER=1
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    infoln "Attempting to create channel ${CHANNEL_NAME}..."
    setGlobals bank 7051
    peer channel create -c ${CHANNEL_NAME} -o orderer.myindo.com:7050 --ordererTLSHostnameOverride orderer.myindo.com -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block --tls --cafile ${ORDERER_CA}
    rc=$?
    COUNTER=$(expr $COUNTER + 1)
  done
  verifyResult $rc "Channel creation failed"
  successln "Channel '${CHANNEL_NAME}' created"
}

# Join channel
joinChannel() {
  ORG=$1
  setGlobals $ORG
  local rc=1
  local COUNTER=1
  ## Sometimes Join takes time, hence retry
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    setGlobals $ORG
    peer channel join -b ./channel-artifacts/${CHANNEL_NAME}.block
    rc=$?
    COUNTER=$(expr $COUNTER + 1)
  done
  verifyResult $rc "After $MAX_RETRY attempts, peer0.${ORG} has failed to join channel '${CHANNEL_NAME}'"
  successln "Peer0.${ORG} joined channel '${CHANNEL_NAME}'"
}

# Update anchor peers
updateAnchorPeers() {
  ORG=$1
  setGlobals $ORG

  local rc=1
  local COUNTER=1
  ## Sometimes Join takes time, hence retry
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    setGlobals $ORG
    peer channel update -o orderer.myindo.com:7050 --ordererTLSHostnameOverride orderer.myindo.com -c ${CHANNEL_NAME} -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls --cafile ${ORDERER_CA}
    rc=$?
    COUNTER=$(expr $COUNTER + 1)
  done
  verifyResult $rc "Anchor peer update failed"
  successln "Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '${CHANNEL_NAME}'"
}

# Generate channel artifacts
createChannelTx() {
  setGlobals bank 7051

  configtxgen -profile MyindoNetworkGenesis -channelID ${CHANNEL_NAME} -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx
  res=$?
  verifyResult $res "Failed to generate channel configuration transaction"

  infoln "Generating anchor peer update transactions for ${CHANNEL_NAME}"

  configtxgen -profile MyindoNetworkGenesis -channelID ${CHANNEL_NAME} -outputAnchorPeersUpdate ./channel-artifacts/BankOrgMSPanchors.tx -asOrg BankOrgMSP
  res=$?
  verifyResult $res "Failed to generate anchor peer update transaction for BankOrgMSP"

  configtxgen -profile MyindoNetworkGenesis -channelID ${CHANNEL_NAME} -outputAnchorPeersUpdate ./channel-artifacts/InsuranceOrgMSPanchors.tx -asOrg InsuranceOrgMSP
  res=$?
  verifyResult $res "Failed to generate anchor peer update transaction for InsuranceOrgMSP"

  configtxgen -profile MyindoNetworkGenesis -channelID ${CHANNEL_NAME} -outputAnchorPeersUpdate ./channel-artifacts/HealthcareOrgMSPanchors.tx -asOrg HealthcareOrgMSP
  res=$?
  verifyResult $res "Failed to generate anchor peer update transaction for HealthcareOrgMSP"
}

# Main execution
if [ "$CHANNEL_NAME" == "" ]; then
  fatalln "Channel name not provided"
fi

# Create channel artifacts if they don't exist
if [ ! -f "channel-artifacts/${CHANNEL_NAME}.tx" ]; then
  infoln "Generating channel artifacts"
  createChannelTx
fi

# Create the channel
infoln "Creating channel '${CHANNEL_NAME}'"
createChannel

# Join all peers to the channel
infoln "Joining bank peers to the channel..."
joinChannel bank

infoln "Joining insurance peers to the channel..."
joinChannel insurance

infoln "Joining healthcare peers to the channel..."
joinChannel healthcare

# Update anchor peers
infoln "Updating anchor peers for bank..."
updateAnchorPeers bank

infoln "Updating anchor peers for insurance..."
updateAnchorPeers insurance

infoln "Updating anchor peers for healthcare..."
updateAnchorPeers healthcare

successln "Channel '${CHANNEL_NAME}' created successfully and all peers joined"
