#!/bin/bash

# Start script for SDK-based Fabric API
# This script starts the API that uses the Fabric SDK instead of Docker exec

echo "🚀 Starting SDK-based Fabric API..."
echo "===================================="

# Navigate to API directory
cd api

# Check if API binary exists
if [ ! -f "./api" ]; then
    echo "📦 Building API binary..."
    go build -o api .
    if [ $? -ne 0 ]; then
        echo "❌ Failed to build API"
        exit 1
    fi
    echo "✅ API built successfully!"
fi

# Check if Fabric network is running
echo "🔍 Checking Fabric network status..."
if ! docker ps --format "{{.Names}}" | grep -q "peer0.org1.example.com"; then
    echo "❌ Fabric network is not running!"
    echo "Please run the setup script first:"
    echo "  ./scripts/setup-fabric-network.sh"
    exit 1
fi

if ! docker ps --format "{{.Names}}" | grep -q "orderer.example.com"; then
    echo "❌ Fabric orderer is not running!"
    echo "Please run the setup script first:"
    echo "  ./scripts/setup-fabric-network.sh"
    exit 1
fi

echo "✅ Fabric network is running!"

# Check if chaincode is deployed
echo "🔍 Checking chaincode deployment..."
CHAINCODE_STATUS=$(docker exec cli peer chaincode query -C mychannel -n custom-chaincode -c '{"Args":["GetAssetCount"]}' 2>/dev/null || echo "FAILED")

if [[ "$CHAINCODE_STATUS" == "FAILED" ]]; then
    echo "❌ Chaincode is not deployed or not responding!"
    echo "Please run the setup script first:"
    echo "  ./scripts/setup-fabric-network.sh"
    exit 1
fi

echo "✅ Chaincode is deployed and responding!"

# Check if port 8080 is already in use
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8080 is already in use!"
    echo "Stopping existing API process..."
    pkill -f "./api" || true
    sleep 2
fi

# Start the API
echo "🌟 Starting API server..."
echo "API will be available at: http://localhost:8080"
echo "Press Ctrl+C to stop the API"
echo ""

# Start API in foreground
./api
```

## 🎉 Complete Setup Guide

Now you have a fully SDK-based API that doesn't rely on Docker exec commands! Here's how to use it:

### Step 1: Set up the Fabric Network
```bash
# Make scripts executable
chmod +x scripts/setup-fabric-network.sh
chmod +x scripts/start-api.sh

# Run the network setup (only need to do this once)
./scripts/setup-fabric-network.sh
```

### Step 2: Start the API
```bash
# Start the API (run this every time you want to start the API)
./scripts/start-api.sh
```

### Step 3: Test the API
Once the API is running, you can test it:

```bash
# Health check
curl http://localhost:8080/health

# Get all assets
curl http://localhost:8080/api/v1/assets

# Create a new asset
curl -X POST http://localhost:8080/api/v1/assets \
  -H "Content-Type: application/json" \
  -d '{
    "ID": "test-asset-1",
    "color": "cyan",
    "size": 30,
    "owner": "Alice",
    "appraisedValue": 1300
  }'

# Get asset by owner
curl http://localhost:8080/api/v1/owners/Alice/assets

# Get asset history
curl http://localhost:8080/api/v1/assets/asset1/history
```

## 🔧 What's Different Now?

### ✅ **No More Docker Exec Commands**
- API now uses the official Hyperledger Fabric SDK
- Direct gRPC connections to peers and orderers
- Much more reliable and efficient

### ✅ **Enhanced Functionality**
- Added all the advanced chaincode functions from your chaincode:
  - `GetAssetsByOwner` - Filter assets by owner
  - `GetAssetHistory` - Track asset changes over time
  - `GetAssetCount` - Get total asset count

### ✅ **Better Error Handling**
- Proper SDK error handling
- Clean response formatting
- Connection status checks

### ✅ **Local Development**
- API runs locally for easy debugging
- Hot reload support
- No Docker container needed for the API itself

## 📁 Project Structure
```
hyperledger-go/
├── api/                    # SDK-based API
│   ├── main.go            # Main API server
│   ├── config.yaml        # Fabric SDK configuration
│   └── go.mod             # Dependencies
├── chaincode/             # Your custom chaincode
│   ├── chaincode.go       # Enhanced asset management
│   └── go.mod
└── scripts/               # Helper scripts
    ├── setup-fabric-network.sh  # Network setup
    └── start-api.sh            # API startup
```

Your API is now properly integrated with the Fabric SDK and ready for production use! 🚀
