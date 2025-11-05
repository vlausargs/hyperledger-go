# Hyperledger Fabric with Go API

This project implements a complete Hyperledger Fabric blockchain solution with a Go REST API using the Gin framework. The implementation includes smart contracts, network setup, and Docker deployment.

## Architecture

- **Hyperledger Fabric Network**: Two organizations (Org1, Org2) with multiple peers
- **Smart Contract**: Asset management chaincode written in Go
- **REST API**: Go application with Gin framework for blockchain interaction
- **Deployment**: Docker Compose for containerized deployment

## Project Structure

```
hyperledger-go/
├── api/                    # Go REST API application
│   ├── main.go            # Main API application with Gin routing
│   ├── go.mod             # Go module dependencies
│   └── Dockerfile         # Docker configuration for API
├── chaincode/             # Hyperledger Fabric smart contract
│   ├── chaincode.go       # Asset management smart contract
│   └── go.mod             # Chaincode dependencies
├── fabric-network/         # Fabric network configuration
│   ├── crypto-config.yaml # Crypto material configuration
│   ├── configtx/          
│   │   └── configtx.yaml  # Channel and genesis block configuration
│   ├── crypto-config/     # Generated cryptographic material (created during setup)
│   └── channel-artifacts/ # Generated channel artifacts (created during setup)
├── scripts/               # Network setup and management scripts
│   ├── generate-crypto.sh # Generate cryptographic material
│   ├── generate-configtx.sh # Generate genesis block and channel config
│   ├── package-chaincode.sh # Package chaincode for deployment
│   ├── setup-network.sh    # Complete network setup script
│   └── teardown-network.sh # Network cleanup script
├── docker-compose.yml     # Docker Compose configuration
└── README.md             # This documentation
```

## Prerequisites

- Docker and Docker Compose
- Go 1.21 or later
- Hyperledger Fabric binaries (cryptogen, configtxgen)
- Make sure Fabric binaries are in your PATH or download them using the Fabric samples

### Installing Fabric Binaries

```bash
# Download Fabric samples and binaries
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.7 1.5.5

# Add to PATH (adjust the path as needed)
export PATH=$PATH:$PWD/fabric-samples/bin
```

## Quick Start

### 1. Setup the Network

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run the complete network setup
./scripts/setup-network.sh
```

This script will:
- Generate cryptographic material
- Create channel configuration
- Start the Fabric network
- Create and join channels
- Install and deploy the chaincode
- Start the API service

### 2. Verify the Installation

```bash
# Check if all containers are running
docker ps

# Test the API health endpoint
curl http://localhost:8080/health
```

## API Endpoints

The REST API provides the following endpoints:

### Health Check
- `GET /health` - Check API health status

### Asset Management
- `GET /api/v1/assets` - Get all assets
- `GET /api/v1/assets/:id` - Get specific asset by ID
- `POST /api/v1/assets` - Create a new asset
  ```json
  {
    "ID": "asset3",
    "color": "green",
    "size": 10,
    "owner": "Alice",
    "appraisedValue": 500
  }
  ```
- `PUT /api/v1/assets/:id` - Update an existing asset
  ```json
  {
    "color": "blue",
    "size": 15,
    "owner": "Bob",
    "appraisedValue": 600
  }
  ```
- `DELETE /api/v1/assets/:id` - Delete an asset
- `POST /api/v1/assets/:id/transfer` - Transfer asset ownership
  ```json
  {
    "newOwner": "Charlie"
  }
  ```

### Ledger Operations
- `POST /api/v1/ledger/init` - Initialize the ledger with sample data

## API Usage Examples

### Create an Asset
```bash
curl -X POST http://localhost:8080/api/v1/assets \
  -H "Content-Type: application/json" \
  -d '{
    "ID": "asset100",
    "color": "purple",
    "size": 20,
    "owner": "David",
    "appraisedValue": 1000
  }'
```

### Get All Assets
```bash
curl http://localhost:8080/api/v1/assets
```

### Get Specific Asset
```bash
curl http://localhost:8080/api/v1/assets/asset1
```

### Transfer Asset
```bash
curl -X POST http://localhost:8080/api/v1/assets/asset1/transfer \
  -H "Content-Type: application/json" \
  -d '{"newOwner": "Eve"}'
```

## Chaincode Functions

The smart contract implements the following functions:

- `InitLedger()` - Initialize the ledger with sample assets
- `CreateAsset(id, color, size, owner, appraisedValue)` - Create a new asset
- `ReadAsset(id)` - Read an asset by ID
- `UpdateAsset(id, color, size, owner, appraisedValue)` - Update an existing asset
- `DeleteAsset(id)` - Delete an asset
- `TransferAsset(id, newOwner)` - Transfer asset ownership
- `GetAllAssets()` - Retrieve all assets

## Network Components

### Organizations
- **Org1**: 2 peers (peer0.org1.example.com, peer1.org1.example.com)
- **Org2**: 2 peers (peer0.org2.example.com, peer1.org2.example.com)

### Services
- **Orderer**: orderer.example.com:7050
- **Peers**: Various ports (7051, 8051, 9051, 10051)
- **API**: localhost:8080
- **CLI**: For network management and debugging

## Management Scripts

### Individual Operations

```bash
# Generate only crypto material
./scripts/generate-crypto.sh

# Generate only channel configuration
./scripts/generate-configtx.sh

# Package chaincode
./scripts/package-chaincode.sh

# Complete network teardown
./scripts/teardown-network.sh
```

### Manual Network Management

```bash
# Start the network
docker-compose up -d

# Stop the network
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Access CLI container
docker exec -it cli bash
```

## Development

### Adding New Chaincode Functions

1. Modify `chaincode/chaincode.go`
2. Rebuild and reinstall the chaincode:
   ```bash
   ./scripts/package-chaincode.sh
   # Then reinstall via CLI or update the setup script
   ```

### Adding New API Endpoints

1. Modify `api/main.go`
2. Rebuild the API:
   ```bash
   cd api
   docker build -t fabric-api .
   docker-compose up -d --force-recreate api
   ```

## Security Considerations

- The current setup uses self-signed certificates (for development only)
- Production environments should use proper certificate authorities
- Network policies should be configured appropriately
- API should include proper authentication and authorization

## Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure ports 7050-10053 and 8080 are available
2. **Docker Issues**: Restart Docker daemon if containers fail to start
3. **Chaincode Installation**: Verify chaincode package is properly created
4. **API Connection**: Check if Fabric SDK configuration matches network setup

### Debug Commands

```bash
# Check container status
docker ps -a

# View container logs
docker logs [container-name]

# Access peer CLI for debugging
docker exec -it cli bash

# Query chaincode directly from CLI
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'
```

## Production Deployment

For production deployment, consider:

1. Using Kubernetes instead of Docker Compose
2. Implementing proper monitoring and logging
3. Setting up proper certificate authorities
4. Configuring network policies and firewalls
5. Implementing backup and disaster recovery
6. Adding API authentication and rate limiting

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided for educational and development purposes. Please ensure compliance with Hyperledger Fabric licensing terms.

## Support

For issues related to:
- Hyperledger Fabric: [Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- Fabric SDK Go: [Fabric SDK Go Repository](https://github.com/hyperledger/fabric-sdk-go)
- Gin Framework: [Gin Documentation](https://gin-gonic.com/docs/)