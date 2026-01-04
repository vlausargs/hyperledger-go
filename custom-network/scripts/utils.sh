#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script provides utility functions for the Hyperledger Fabric network
# management scripts. It includes functions for logging, error handling,
# and common operations.

# ANSI escape codes for colors
BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
GRAY="\033[0;90m"

# Bold colors
BOLD_BLACK="\033[1;30m"
BOLD_RED="\033[1;31m"
BOLD_GREEN="\033[1;32m"
BOLD_YELLOW="\033[1;33m"
BOLD_BLUE="\033[1;34m"
BOLD_MAGENTA="\033[1;35m"
BOLD_CYAN="\033[1;36m"
BOLD_WHITE="\033[1;37m"

# Background colors
BG_BLACK="\033[40m"
BG_RED="\033[41m"
BG_GREEN="\033[42m"
BG_YELLOW="\033[43m"
BG_BLUE="\033[44m"
BG_MAGENTA="\033[45m"
BG_CYAN="\033[46m"
BG_WHITE="\033[47m"

# Reset color
NC="\033[0m"

# Logging functions
infoln() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warnln() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

errorln() {
  echo -e "${RED}[ERROR]${NC} $1"
}

fatalln() {
  echo -e "${BOLD_RED}[FATAL]${NC} $1"
  exit 1
}

successln() {
  echo -e "${BOLD_GREEN}[SUCCESS]${NC} $1"
}

# Function to verify the result of the previous operation
verifyResult() {
  if [ $1 -ne 0 ]; then
    errorln "Error in command execution. Exiting..."
    exit 1
  fi
}

# Function to set environment variables for a peer organization
setGlobals() {
  local ORG=$1
  local PEER_PORT=$2

  if [ "$ORG" == "bank" ]; then
    export CORE_PEER_LOCALMSPID="BankOrgMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/bank.myindo.com/peers/peer0.bank.myindo.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/bank.myindo.com/users/Admin@bank.myindo.com/msp
    export CORE_PEER_ADDRESS=peer0.bank.myindo.com:7051
  elif [ "$ORG" == "insurance" ]; then
    export CORE_PEER_LOCALMSPID="InsuranceOrgMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/insurance.myindo.com/peers/peer0.insurance.myindo.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/insurance.myindo.com/users/Admin@insurance.myindo.com/msp
    export CORE_PEER_ADDRESS=peer0.insurance.myindo.com:9051
  elif [ "$ORG" == "healthcare" ]; then
    export CORE_PEER_LOCALMSPID="HealthcareOrgMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/healthcare.myindo.com/peers/peer0.healthcare.myindo.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/healthcare.myindo.com/users/Admin@healthcare.myindo.com/msp
    export CORE_PEER_ADDRESS=peer0.healthcare.myindo.com:11051
  else
    errorln "Unknown organization: $ORG"
    exit 1
  fi

  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}

# Function to check if a command exists
commandExists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to wait for a container to be ready
waitForContainer() {
  local CONTAINER_NAME=$1
  local MAX_RETRIES=${3:-30}
  local RETRY_INTERVAL=${2:-2}
  local RETRY_COUNT=0

  echo "Waiting for container $CONTAINER_NAME to be ready..."

  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker ps | grep -q "$CONTAINER_NAME" && docker logs "$CONTAINER_NAME" 2>&1 | grep -q "Started"; then
      successln "Container $CONTAINER_NAME is ready"
      return 0
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES..."
    sleep $RETRY_INTERVAL
  done

  errorln "Container $CONTAINER_NAME is not ready after $MAX_RETRIES attempts"
  return 1
}

# Function to generate random string
randomString() {
  local LENGTH=${1:-8}
  if commandExists openssl; then
    openssl rand -hex $((LENGTH / 2)) | cut -c1-$LENGTH
  else
    # Fallback method
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $LENGTH
  fi
}

# Function to create necessary directories
createDirs() {
  mkdir -p organizations/peerOrganizations
  mkdir -p organizations/ordererOrganizations
  mkdir -p channel-artifacts
  mkdir -p system-genesis-block
}

# Function to check if docker is running
checkDocker() {
  if ! docker info >/dev/null 2>&1; then
    errorln "Cannot connect to the Docker daemon. Is the docker daemon running?"
    exit 1
  fi
}

# Function to check if docker-compose is available
checkDockerCompose() {
  if ! commandExists docker-compose && ! docker compose version >/dev/null 2>&1; then
    errorln "docker-compose is not installed or not available in PATH"
    exit 1
  fi
}

# Function to parse command line arguments
parseArgs() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -c|--channel)
        CHANNEL_NAME="$2"
        shift 2
        ;;
      -o|--org)
        ORG="$2"
        shift 2
        ;;
      -t|--timeout)
        CLI_TIMEOUT="$2"
        shift 2
        ;;
      -n|--chaincode-name)
        CC_NAME="$2"
        shift 2
        ;;
      -p|--chaincode-path)
        CC_SRC_PATH="$2"
        shift 2
        ;;
      -l|--chaincode-language)
        CC_SRC_LANGUAGE="$2"
        shift 2
        ;;
      -v|--version)
        CC_VERSION="$2"
        shift 2
        ;;
      -s|--sequence)
        CC_SEQUENCE="$2"
        shift 2
        ;;
      -i|--init)
        CC_INIT_FCN="$2"
        shift 2
        ;;
      -h|--help)
        printHelp
        exit 0
        ;;
      -d|--debug)
        VERBOSE=true
        shift
        ;;
      *)
        errorln "Unknown option: $1"
        printHelp
        exit 1
        ;;
    esac
  done
}

# Function to print script usage
printHelp() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -c, --channel <channel_name>    Channel name (default: mychannel)"
  echo "  -o, --org <organization>         Organization (bank, insurance, healthcare)"
  echo "  -t, --timeout <seconds>         CLI timeout (default: 10)"
  echo "  -n, --chaincode-name <name>      Chaincode name"
  echo "  -p, --chaincode-path <path>      Chaincode source path"
  echo "  -l, --chaincode-language <lang>  Chaincode language (go, java, node)"
  echo "  -v, --version <version>          Chaincode version"
  echo "  -s, --sequence <sequence>        Chaincode sequence"
  echo "  -i, --init <function>            Chaincode init function"
  echo "  -d, --debug                      Enable debug mode"
  echo "  -h, --help                       Show this help message"
  echo ""
}

# Function to validate required environment variables
validateEnv() {
  local REQUIRED_VARS=("$@")
  local MISSING_VARS=()

  for VAR in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!VAR}" ]]; then
      MISSING_VARS+=("$VAR")
    fi
  done

  if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    errorln "Missing required environment variables: ${MISSING_VARS[*]}"
    exit 1
  fi
}

# Function to create timestamp for logging
timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Function to log with timestamp
logWithTimestamp() {
  local LEVEL=$1
  shift
  local MESSAGE="$*"
  echo "$(timestamp) [$LEVEL] $MESSAGE"
}

# Function to cleanup on script exit
cleanup() {
  echo "Performing cleanup..."
  # Add any cleanup operations here
}

# Set up trap for cleanup
trap cleanup EXIT

# Export functions for use in other scripts
export -f infoln warnln errorln fatalln successln
export -f verifyResult setGlobals commandExists
export -f waitForContainer randomString createDirs
export -f checkDocker checkDockerCompose parseArgs
export -f printHelp validateEnv timestamp logWithTimestamp
