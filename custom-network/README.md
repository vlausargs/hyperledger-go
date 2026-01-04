# Custom Hyperledger Fabric Network

This is a custom Hyperledger Fabric network deployment based on the Hyperledger Fabric test-network reference. The network consists of three organizations with one peer each, and a single node Raft ordering service.

## Network Architecture

### Organizations
- **BankOrg** - Banking organization with peer `peer0.bank.myindo.com:7051`
- **InsuranceOrg** - Insurance organization with peer `peer0.insurance.myindo.com:9051`
- **HealthcareOrg** - Healthcare organization with peer `peer0.healthcare.myindo.com:11051`
- **OrdererOrg** - Ordering service organization with orderer `orderer.myindo.com:7050`

### Components
- **Orderer**: Single Raft ordering node
- **Peers**: One peer per organization (3 total)
- **Channel**: Default channel named `myindochannel`
- **TLS**: Enabled for all components
- **Crypto Material**: Generated using cryptogen

## Prerequisites

1. **Docker** and **Docker Compose** installed
2. **Hyperledger Fabric binaries** (v2.5.10) in `../bin/` directory:
   - `cryptogen`
   - `configtxgen`
   - `peer`
   - `orderer`
3. **Hyperledger Fabric Docker images** tagged as `2.5.10`:
   - `hyperledger/fabric-peer:2.5.10`
   - `hyperledger/fabric-orderer:2.5.10`
   - `hyperledger/fabric-tools:2.5.10`
   - `hyperledger/fabric-ca:latest`

## Directory Structure

```
custom-network/
├── compose/
│   ├── compose-custom-net.yaml    # Docker Compose for network components
│   └── compose-ca.yaml           # Docker Compose for CAs (optional)
├── configtx/
│   ├── configtx.yaml             # Network configuration
│   └── crypto-config.yaml        # Crypto material configuration
├── organizations/                # Generated crypto material
├── system-genesis-block/         # Genesis block
├── channel-artifacts/           # Channel artifacts
├── scripts/
│   ├── utils.sh                  # Utility functions
│   ├── createChannel.sh          # Channel creation script
│   └── createCrypto.sh           # Crypto material generation
├── network.sh                    # Main network management script
└── README.md                     # This file
```

## Usage

### 1. Generate Crypto Material and Artifacts

```bash
# Generate crypto material only
./network.sh generate

# Or generate crypto material using dedicated script
./scripts/createCrypto.sh
```

### 2. Start the Network

```bash
# Start the complete network (generates crypto if needed)
./network.sh up
```

This will:
- Generate crypto material (if not exists)
- Start orderer and peers
- Create the `myindochannel`
- Join all peers to the channel
- Set anchor peers

### 3. Stop the Network

```bash
# Stop and remove containers
./network.sh down
```

### 4. Restart the Network

```bash
# Stop and restart the network
./network.sh restart
```

### 5. Create Channel Artifacts Only

```bash
# Generate channel configuration files
./network.sh createChannel
```

## Network Operations

### Accessing the CLI

Once the network is up, you can access the CLI container:

```bash
docker exec -it cli bash
```

### Environment Variables

Set the following environment variables for different organizations:

```bash
# For BankOrg
export CORE_PEER_LOCALMSPID="BankOrgMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/bank.myindo.com/peers/peer0.bank.myindo.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/bank.myindo.com/users/Admin@bank.myindo.com/msp
export CORE_PEER_ADDRESS=peer0.bank.myindo.com:7051

# For InsuranceOrg
export CORE_PEER_LOCALMSPID="InsuranceOrgMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/insurance.myindo.com/peers/peer0.insurance.myindo.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/insurance.myindo.com/users/Admin@insurance.myindo.com/msp
export CORE_PEER_ADDRESS=peer0.insurance.myindo.com:9051

# For HealthcareOrg
export CORE_PEER_LOCALMSPID="HealthcareOrgMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/healthcare.myindo.com/peers/peer0.healthcare.myindo.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/healthcare.myindo.com/users/Admin@healthcare.myindo.com/msp
export CORE_PEER_ADDRESS=peer0.healthcare.myindo.com:11051
```

### Common CLI Commands

```bash
# Query channels
peer channel list

# Get channel info
peer channel getinfo -c myindochannel

# Fetch blocks
peer channel fetch newest -c myindochannel

# Join a peer to channel (if needed)
peer channel join -b ./channel-artifacts/myindochannel.block
```

## Port Mappings

| Service | Host Port | Container Port |
|---------|-----------|----------------|
| Orderer | 7050 | 7050 |
| Orderer Admin | 7053 | 7053 |
| Orderer Metrics | 9443 | 9443 |
| Bank Peer | 7051 | 7051 |
| Bank Peer Metrics | 9444 | 9444 |
| Insurance Peer | 9051 | 9051 |
| Insurance Peer Metrics | 9445 | 9445 |
| Healthcare Peer | 11051 | 11051 |
| Healthcare Peer Metrics | 9446 | 9446 |

## Troubleshooting

### Common Issues

1. **Binaries not found**: Ensure Fabric binaries are in `../bin/` directory
2. **Version mismatch**: Check that all Docker images are tagged as `2.5.10`
3. **Port conflicts**: Ensure the host ports are not already in use
4. **Permission issues**: Run scripts with appropriate permissions

### Cleanup

If you need to completely clean the network:

```bash
# Stop network
./network.sh down

# Remove all generated artifacts
rm -rf organizations/
rm -rf channel-artifacts/
rm -rf system-genesis-block/

# Remove Docker volumes
docker volume prune -f
```

### Logs

To view logs for specific components:

```bash
# Orderer logs
docker logs orderer.myindo.com -f

# Bank peer logs
docker logs peer0.bank.myindo.com -f

# Insurance peer logs
docker logs peer0.insurance.myindo.com -f

# Healthcare peer logs
docker logs peer0.healthcare.myindo.com -f
```

## Customization

### Adding New Organizations

1. Update `configtx/crypto-config.yaml` with new organization
2. Update `configtx/configtx.yaml` with new organization definition
3. Update `compose/compose-custom-net.yaml` with new peer service
4. Modify scripts to handle the new organization

### Changing Channel Names

1. Update channel name in `scripts/createChannel.sh`
2. Update any references in other scripts

### Modifying Ports

1. Update port mappings in `compose/compose-custom-net.yaml`
2. Update any scripts that reference specific ports

## Security Notes

- All components use TLS encryption
- Crypto material is generated using cryptogen
- For production use, consider using Fabric CAs instead of cryptogen
- Regularly rotate certificates in production environments

## Support

This network is based on Hyperledger Fabric v2.5.10 and follows the official documentation patterns. For more information, refer to:

- [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- [Fabric Samples Test Network](https://github.com/hyperledger/fabric-samples/tree/main/test-network)
- [Fabric Deployment Guide](https://hyperledger-fabric.readthedocs.io/en/latest/deployment_guide_overview.html)

## License

This code follows the same license as Hyperledger Fabric - Apache License 2.0.