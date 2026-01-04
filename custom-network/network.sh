#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This script brings up a custom Hyperledger Fabric network for testing smart contracts
# and applications. The custom network consists of three organizations with one
# peer each, and a single node Raft ordering service.

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
#
# However using PWD in the path has the side effect that location that
# this script is run from is critical. To ease this, get the directory
# this script is actually in and infer location from there. (putting first)

ROOTDIR=$(cd "$(dirname "$0")" && pwd)
export PATH=${ROOTDIR}/../../hyperledger/fabric-samples/bin:${PWD}/../../hyperledger/fabric-samples/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false

# push to the required directory & set a trap to go back if needed
pushd ${ROOTDIR} > /dev/null
trap "popd > /dev/null" EXIT

. scripts/utils.sh

# Container CLI settings
: ${CONTAINER_CLI:="docker"}
: ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

# Obtain CONTAINER_IDS and remove them
# This function is called when you bring a network down
function clearContainers() {
  infoln "Removing remaining containers"
  ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter label=service=hyperledger-fabric) 2>/dev/null || true
  ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter name='dev-peer*') 2>/dev/null || true
}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
# This function is called when you bring the network down
function removeUnwantedImages() {
  infoln "Removing generated chaincode docker images"
  ${CONTAINER_CLI} image rm -f $(${CONTAINER_CLI} images -aq --filter reference='dev-peer*') 2>/dev/null || true
}

# Versions of fabric known not to work with this release of first-network
BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\. ^1\.2\. ^1\.3\. ^1\.4\."

# Do some basic sanity checking to make sure that the appropriate versions of
# fabric binaries/images are available. In the future, additional checking
# will be added for private key file sizes, etc.
function checkPrereqs() {
  ## Check if you have cloned the peer binaries and configuration files.
  binVersion=$(${CONTAINER_CLI} run --rm hyperledger/fabric-tools:2.5.10 peer version | sed -ne 's/ Version: //p')
  binVersion=$(echo $binVersion | sed 's/^v//')
  if [ "$binVersion" != "2.5.10" ] && [ "$binVersion" != "2.5.4" ]; then
    echo "Expected binaries version 2.5.10 or 2.5.4, got $binVersion"
    exit 1
  fi
  for imagetag in peer orderer tools; do
    echo "=========> IMAGE: $imagetag"
    ${CONTAINER_CLI} image list | grep hyperledger/fabric-$imagetag | grep 2.5.10
  done

  LOCAL_VERSION=$(configtxgen --version | sed -ne 's/ Version: //p')
  LOCAL_VERSION=$(echo $LOCAL_VERSION | sed 's/^v//')
  if [ "$LOCAL_VERSION" != "2.5.10" ] && [ "$LOCAL_VERSION" != "2.5.4" ]; then
    echo "Expected configtxgen version 2.5.10 or 2.5.4, got $LOCAL_VERSION"
    exit 1
  fi

  # use the fabric tools container to see if the binaries and images are on the same version
  CURRENT_VERSION=$(${CONTAINER_CLI} run --rm hyperledger/fabric-tools:2.5.10 peer version | sed -ne 's/ Version: //p' | head -1)

  echo "=========> binaries version: $CURRENT_VERSION"

  for UNSUPPORTED_VERSION in $BLACKLISTED_VERSIONS; do
    infoln "$UNSUPPORTED_VERSION version is not supported"
  done

  echo "Checking for cryptogen..."
  if ! [ -f "${ROOTDIR}/../../hyperledger/fabric-samples/bin/cryptogen" ]; then
    echo "cryptogen binary not found.. exiting"
    exit 1
  fi

  echo "Checking for configtxgen..."
  if ! [ -f "${ROOTDIR}/../../hyperledger/fabric-samples/bin/configtxgen" ]; then
    echo "configtxgen binary not found.. exiting"
    exit 1
  fi
}

# Generate the needed certificates, the genesis block and start the network.
function networkUp() {
  checkPrereqs

  # generate artifacts if they don't exist
  if [ ! -d "organizations/peerOrganizations" ]; then
    echo "Creating organizations..."
    createOrgs
  fi

  echo "Starting orderer and peers..."
  ${CONTAINER_CLI_COMPOSE} -f compose/compose-custom-net.yaml up -d
  echo "Sleeping 15s to allow orderer and peers to complete booting..."
  sleep 15

  ## Create channel
  echo "Creating channel..."
  scripts/createChannel.sh myindochannel
}

function createOrgs() {
  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi

  # Create crypto material using cryptogen
  which cryptogen
  if [ "$?" -ne 0 ]; then
    fatalln "cryptogen tool not found. exiting"
  fi
  infoln "Generating certificates using cryptogen tool"

  infoln "Creating Myindo Network Identities"
  set -x
  cryptogen generate --config=configtx/configtx.yaml --output="organizations"
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate certificates..."
  fi

  ## Create configtx.yaml
  infoln "Generating Orderer Genesis block"

  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  set -x
  configtxgen -profile MyindoNetworkGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate orderer genesis block..."
  fi
}

# Tear down running network
function networkDown() {
  # stop org3 containers also in addition to org1 and org2, in case we were running sample to add org3
  infoln "Stopping network"
  ${CONTAINER_CLI_COMPOSE} -f compose/compose-custom-net.yaml down --volumes --remove-orphans

  # Don't remove the generated artifacts -- note, these are named
  # mychannel.block, mychannel.tx, etc.  We may want to reuse these at a later
  # date in case we want to recreate the network using the same crypto material.
  # If you want to delete these artifacts, you can run:
  # rm -rf channel-artifacts
  # rm -rf organizations

  # remove the local state
  ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'rm -rf /data/production-orderer/* /data/production-bank/* /data/production-insurance/* /data/production-healthcare/*'

  # remove orderer block and other channel configuration transactions and certs
  ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'rm -rf /data/channel-artifacts/* /data/system-genesis-block/*'

  # clean up any chaincode images if they exist
  removeUnwantedImages
}

# Create channel artifacts
function createChannel() {
  # Create channel artifacts directory
  mkdir -p channel-artifacts

  # Generate channel configuration transaction
  configtxgen -profile MyindoNetworkGenesis -channelID myindochannel -outputCreateChannelTx ./channel-artifacts/myindochannel.tx
  res=$?
  verifyResult $res "Failed to generate channel configuration transaction"

  # Generate anchor peer updates for each organization
  configtxgen -profile MyindoNetworkGenesis -channelID myindochannel -outputAnchorPeersUpdate ./channel-artifacts/BankOrgMSPanchors.tx -asOrg BankOrgMSP
  res=$?
  verifyResult $res "Failed to generate anchor peer update for BankOrgMSP"

  configtxgen -profile MyindoNetworkGenesis -channelID myindochannel -outputAnchorPeersUpdate ./channel-artifacts/InsuranceOrgMSPanchors.tx -asOrg InsuranceOrgMSP
  res=$?
  verifyResult $res "Failed to generate anchor peer update for InsuranceOrgMSP"

  configtxgen -profile MyindoNetworkGenesis -channelID myindochannel -outputAnchorPeersUpdate ./channel-artifacts/HealthcareOrgMSPanchors.tx -asOrg HealthcareOrgMSP
  res=$?
  verifyResult $res "Failed to generate anchor peer update for HealthcareOrgMSP"
}

# Verify result
function verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}

# Print help function
function printHelp() {
  echo "Usage: "
  echo "  network.sh <mode> [flags]"
  echo "    <mode> - one of 'up', 'down', 'createChannel', 'restart', 'generate'"
  echo
  echo "Flags:"
  echo "  -h - print this message"
  echo
  echo "Modes:"
  echo "  up                - Start the network"
  echo "  down              - Stop the network"
  echo "  restart           - Restart the network"
  echo "  createChannel     - Create channel artifacts"
  echo "  generate          - Generate crypto material and certificates"
}

# Parse command line arguments
MODE=$1
shift

# Determine whether starting, stopping, restarting, generating or upgrading
if [ "$MODE" == "up" ]; then
  EXPMODE="Starting"
elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping"
elif [ "$MODE" == "restart" ]; then
  EXPMODE="Restarting"
elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and genesis block"
elif [ "$MODE" == "createChannel" ]; then
  EXPMODE="Creating channel artifacts"
else
  printHelp
  exit 1
fi

if [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "createChannel" ]; then
  createChannel
elif [ "${MODE}" == "down" ]; then
  networkDown
elif [ "${MODE}" == "restart" ]; then
  networkDown
  networkUp
elif [ "${MODE}" == "generate" ]; then
  createOrgs
else
  printHelp
  exit 1
fi
