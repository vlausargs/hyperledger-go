#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script deploys a chaincode to the Hyperledger Fabric network

CHANNEL_NAME=${1:-"myindochannel"}
CC_NAME=${2:-"basic"}
CC_SRC_PATH=${3:-"../chaincode"}
CC_SRC_LANGUAGE=${4:-"go"}
CC_VERSION=${5:-"1.0"}
CC_SEQUENCE=${6:-"1"}
CC_INIT_FCN=${7:-""}
DELAY=${8:-"3"}
MAX_RETRY=${9:-"5"}
VERBOSE=${10:-"false"}

. scripts/utils.sh

# Set the orderer CA
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/myindo.com/orderers/orderer.myindo.com/msp/tlscacerts/tlsca.myindo.com-cert.pem

# Package chaincode
packageChaincode() {
  ORG=$1
  setGlobals $ORG

  if [ "$CC_SRC_LANGUAGE" = "go" ]; then
    CC_RUNTIME_LANGUAGE=golang
  elif [ "$CC_SRC_LANGUAGE" = "java" ]; then
    CC_RUNTIME_LANGUAGE=java
  elif [ "$CC_SRC_LANGUAGE" = "node" ]; then
    CC_RUNTIME_LANGUAGE=node
  else
    fatalln "The chaincode language ${CC_SRC_LANGUAGE} is not supported by this script"
    exit 1
  fi

  infoln "Packaging chaincode for ${ORG}..."

  set -x
  peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${CC_VERSION}
  { set +x; } 2>/dev/null
  res=$?
  verifyResult $res "Chaincode packaging has failed"
  successln "Chaincode is packaged"
}

# Install chaincode
installChaincode() {
  ORG=$1
  setGlobals $ORG

  infoln "Installing chaincode on peer0.${ORG}..."

  set -x
  peer lifecycle chaincode install ${CC_NAME}.tar.gz
  { set +x; } 2>/dev/null
  res=$?
  verifyResult $res "Chaincode installation on peer0.${ORG} has failed"
  successln "Chaincode is installed on peer0.${ORG}"
}

# Query installed chaincodes
queryInstalled() {
  ORG=$1
  setGlobals $ORG

  infoln "Querying installed chaincodes on peer0.${ORG}..."
  set -x
  peer lifecycle chaincode queryinstalled >&log.txt
  cat log.txt
  PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
  { set +x; } 2>/dev/null
  successln "Query installed successful on peer0.${ORG} on channel"
}

# Approve chaincode for organization
approveForMyOrg() {
  ORG=$1
  setGlobals $ORG

  if [ -z "$PACKAGE_ID" ]; then
    fatalln "PACKAGE_ID not set. Call queryInstalled first"
  fi

  infoln "Approving chaincode for ${ORG}..."

  set -x
  peer lifecycle chaincode approveformyorg -o orderer.myindo.com:7050 --ordererTLSHostnameOverride orderer.myindo.com --tls --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED}
  { set +x; } 2>/dev/null
  res=$?
  verifyResult $res "Chaincode definition approval on peer0.${ORG} has failed"
  successln "Chaincode definition approved on peer0.${ORG}"
}

# Check commit readiness
checkCommitReadiness() {
  ORG=$1
  shift 1
  setGlobals $ORG

  infoln "Checking the commit readiness of the chaincode definition on peer0.${ORG}..."

  local rc=1
  local COUNTER=1
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to check the commit readiness of the chaincode definition on peer0.${ORG}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} --output json
    { set +x; } 2>/dev/null
    res=$?
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    successln "Checking the commit readiness of the chaincode definition successful on peer0.${ORG}"
  else
    fatalln "After $MAX_RETRY attempts, Check commit readiness result on peer0.${ORG} is INVALID!"
  fi
}

# Commit chaincode definition
commitChaincodeDefinition() {
  parsePeerConnectionParameters $@

  res=$?
  verifyResult $res "Peer connection parameters preparation failed"

  while [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    infoln "Attempting to commit chaincode definition on ${CHANNEL_NAME}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode commit -o orderer.myindo.com:7050 --ordererTLSHostnameOverride orderer.myindo.com --tls --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} $PEER_CONN_PARMS --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED}
    { set +x; } 2>/dev/null
    res=$?
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "Chaincode definition commit failed"
  successln "Chaincode definition committed on channel ${CHANNEL_NAME}"
}

# Query committed chaincode definition
queryCommitted() {
  ORG=$1
  setGlobals $ORG

  infoln "Querying chaincode definition on peer0.${ORG} on channel ${CHANNEL_NAME}..."
  set -x
  peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME}
  { set +x; } 2>/dev/null
}

# Initialize chaincode
chaincodeInvokeInit() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Peer connection parameters preparation failed"

  if [ "$CC_INIT_FCN" = "" ]; then
    infoln "Chaincode initialization is not required"
    return
  fi

  infoln "Initializing chaincode on channel ${CHANNEL_NAME} using function ${CC_INIT_FCN}..."
  set -x
  fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
  peer chaincode invoke -o orderer.myindo.com:7050 --ordererTLSHostnameOverride orderer.myindo.com --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n ${CC_NAME} $PEER_CONN_PARMS -c ${fcn_call}
  { set +x; } 2>/dev/null
  res=$?
  verifyResult $res "Chaincode initialization failed"
  successln "Chaincode initialized successfully"
}

# Parse peer connection parameters
parsePeerConnectionParameters() {
  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1
    PEER="peer0.$1"
    ## Set peer addresses
    if [ -z "$PEERS" ]
    then
      PEERS="$PEER"
    else
      PEERS="$PEERS $PEER"
    fi
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    ## Set path to TLS certificate
    TLSINFO=$(eval echo "--tlsRootCertFiles \$CORE_PEER_TLS_ROOTCERT_FILE")
    PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
    shift
  done
  infoln "Peer connection parameters: $PEER_CONN_PARMS"
}

# Set init required flag
if [ "$CC_INIT_FCN" = "" ]; then
  INIT_REQUIRED=""
else
  INIT_REQUIRED="--init-required"
fi

# Main execution
infoln "Starting chaincode deployment..."

# Package chaincode
packageChaincode bank

# Install on all peers
installChaincode bank
installChaincode insurance
installChaincode healthcare

# Query installed to get package ID
queryInstalled bank

# Set package ID for other organizations
for org in insurance healthcare; do
  queryInstalled $org
done

# Approve for all organizations
approveForMyOrg bank
approveForMyOrg insurance
approveForMyOrg healthcare

# Check commit readiness
checkCommitReadiness bank
checkCommitReadiness insurance
checkCommitReadiness healthcare

# Commit chaincode definition
commitChaincodeDefinition bank insurance healthcare

# Query committed
queryCommitted bank
queryCommitted insurance
queryCommitted healthcare

# Initialize chaincode if init function provided
chaincodeInvokeInit bank insurance healthcare

successln "Chaincode deployment completed successfully!"
