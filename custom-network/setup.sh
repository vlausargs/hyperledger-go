#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script helps set up the Hyperledger Fabric binaries and prerequisites
# for the custom network

FABRIC_VERSION="2.5.10"
CA_VERSION="1.5.12"
ARCH=$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/mingw64_nt.*/windows/')
PLATFORM=${ARCH}-$(uname -m | sed 's/x86_64/amd64/g')
BINARIES_DIR="./bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check Docker
    if ! command_exists docker; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check Docker Compose
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi

    # Check curl
    if ! command_exists curl; then
        error "curl is not installed. Please install curl first."
        exit 1
    fi

    log "Prerequisites check passed!"
}

# Download Fabric binaries
download_fabric_binaries() {
    log "Downloading Hyperledger Fabric binaries v${FABRIC_VERSION}..."

    # Create binaries directory
    mkdir -p ${BINARIES_DIR}
    cd ${BINARIES_DIR}

    # Download the platform-specific binary
    BINARY_FILE="hyperledger-fabric-${PLATFORM}-${FABRIC_VERSION}.tar.gz"

    if [ ! -f "${BINARY_FILE}" ]; then
        log "Downloading ${BINARY_FILE}..."
        curl -sSL https://github.com/hyperledger/fabric/releases/download/v${FABRIC_VERSION}/${BINARY_FILE} | tar xz
    else
        log "Binary file already exists, skipping download."
    fi

    # Download CA binaries
    CA_BINARY_FILE="hyperledger-fabric-ca-${PLATFORM}-${CA_VERSION}.tar.gz"

    if [ ! -f "${CA_BINARY_FILE}" ]; then
        log "Downloading ${CA_BINARY_FILE}..."
        curl -sSL https://github.com/hyperledger/fabric-ca/releases/download/v${CA_VERSION}/${CA_BINARY_FILE} | tar xz
    else
        log "CA binary file already exists, skipping download."
    fi

    cd ..
}

# Pull Docker images
pull_docker_images() {
    log "Pulling Hyperledger Fabric Docker images..."

    # Pull Fabric images
    docker pull hyperledger/fabric-peer:${FABRIC_VERSION}
    docker pull hyperledger/fabric-orderer:${FABRIC_VERSION}
    docker pull hyperledger/fabric-tools:${FABRIC_VERSION}
    docker pull hyperledger/fabric-ccenv:${FABRIC_VERSION}
    docker pull hyperledger/fabric-baseos:${FABRIC_VERSION}

    # Pull CA images
    docker pull hyperledger/fabric-ca:${CA_VERSION}

    # Tag images as latest (optional)
    docker tag hyperledger/fabric-peer:${FABRIC_VERSION} hyperledger/fabric-peer:latest
    docker tag hyperledger/fabric-orderer:${FABRIC_VERSION} hyperledger/fabric-orderer:latest
    docker tag hyperledger/fabric-tools:${FABRIC_VERSION} hyperledger/fabric-tools:latest
    docker tag hyperledger/fabric-ca:${CA_VERSION} hyperledger/fabric-ca:latest

    log "Docker images pulled successfully!"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."

    # Check binaries
    local binaries=("cryptogen" "configtxgen" "peer" "orderer" "fabric-ca-client")
    for binary in "${binaries[@]}"; do
        if [ -f "${BINARIES_DIR}/${binary}" ]; then
            log "✓ ${binary} found"
        else
            error "✗ ${binary} not found"
            return 1
        fi
    done

    # Check Docker images
    local images=("hyperledger/fabric-peer:${FABRIC_VERSION}" "hyperledger/fabric-orderer:${FABRIC_VERSION}" "hyperledger/fabric-tools:${FABRIC_VERSION}")
    for image in "${images[@]}"; do
        if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "${image}"; then
            log "✓ ${image} found"
        else
            error "✗ ${image} not found"
            return 1
        fi
    done

    log "Installation verification completed successfully!"
}

# Setup PATH
setup_path() {
    log "Setting up PATH..."

    # Add to current session
    export PATH=${PWD}/${BINARIES_DIR}:$PATH

    # Add to shell profile
    local shell_profile=""
    if [ -n "$BASH_VERSION" ]; then
        shell_profile="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_profile="$HOME/.zshrc"
    fi

    if [ -n "$shell_profile" ] && [ -f "$shell_profile" ]; then
        if ! grep -q "${PWD}/${BINARIES_DIR}" "$shell_profile"; then
            echo "" >> "$shell_profile"
            echo "# Hyperledger Fabric binaries" >> "$shell_profile"
            echo "export PATH=${PWD}/${BINARIES_DIR}:\$PATH" >> "$shell_profile"
            log "Added Fabric binaries to PATH in $shell_profile"
        fi
    fi
}

# Clean up function
cleanup() {
    log "Cleaning up..."
    # Add any cleanup operations here
}

# Show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -b, --binaries Only download binaries"
    echo "  -d, --docker   Only pull Docker images"
    echo "  -v, --verify   Only verify installation"
    echo "  -c, --clean    Clean up downloaded files"
    echo ""
    echo "If no options are provided, the script will perform a complete setup."
}

# Main execution
main() {
    local DOWNLOAD_BINARIES=true
    local PULL_IMAGES=true
    local VERIFY_ONLY=false
    local CLEAN_ONLY=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -b|--binaries)
                DOWNLOAD_BINARIES=true
                PULL_IMAGES=false
                shift
                ;;
            -d|--docker)
                DOWNLOAD_BINARIES=false
                PULL_IMAGES=true
                shift
                ;;
            -v|--verify)
                VERIFY_ONLY=true
                shift
                ;;
            -c|--clean)
                CLEAN_ONLY=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Clean up if requested
    if [ "$CLEAN_ONLY" = true ]; then
        log "Cleaning up..."
        rm -rf ${BINARIES_DIR}
        docker rmi -f $(docker images "hyperledger/fabric-*" -q) 2>/dev/null || true
        log "Cleanup completed!"
        exit 0
    fi

    # Verify only if requested
    if [ "$VERIFY_ONLY" = true ]; then
        verify_installation
        exit $?
    fi

    # Set up trap for cleanup
    trap cleanup EXIT

    # Check prerequisites
    check_prerequisites

    # Download binaries if requested
    if [ "$DOWNLOAD_BINARIES" = true ]; then
        download_fabric_binaries
        setup_path
    fi

    # Pull Docker images if requested
    if [ "$PULL_IMAGES" = true ]; then
        pull_docker_images
    fi

    # Verify installation
    verify_installation

    log ""
    log "🎉 Hyperledger Fabric setup completed successfully!"
    log ""
    log "Next steps:"
    log "1. Start the network: ./network.sh up"
    log "2. Deploy chaincode: ./scripts/deployCC.sh"
    log "3. Stop the network: ./network.sh down"
    log ""
    log "For more information, see README.md"
}

# Run main function with all arguments
main "$@"
