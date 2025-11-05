package main

import (
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path"

	"github.com/gin-gonic/gin"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-gateway/pkg/identity"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

// Asset represents structure of an asset
type Asset struct {
	ID             string `json:"ID"`
	Color          string `json:"color"`
	Size           int    `json:"size"`
	Owner          string `json:"owner"`
	AppraisedValue int    `json:"appraisedValue"`
	CreatedAt      string `json:"createdAt,omitempty"`
	UpdatedAt      string `json:"updatedAt,omitempty"`
}

// CreateAssetRequest represents the request to create an asset
type CreateAssetRequest struct {
	ID             string `json:"ID" binding:"required"`
	Color          string `json:"color" binding:"required"`
	Size           int    `json:"size" binding:"required"`
	Owner          string `json:"owner" binding:"required"`
	AppraisedValue int    `json:"appraisedValue" binding:"required"`
}

// UpdateAssetRequest represents the request to update an asset
type UpdateAssetRequest struct {
	Color          string `json:"color" binding:"required"`
	Size           int    `json:"size" binding:"required"`
	Owner          string `json:"owner" binding:"required"`
	AppraisedValue int    `json:"appraisedValue" binding:"required"`
}

// TransferAssetRequest represents the request to transfer an asset
type TransferAssetRequest struct {
	NewOwner string `json:"newOwner" binding:"required"`
}

// AssetHistory represents the history of an asset
type AssetHistory struct {
	AssetID   string `json:"assetId"`
	Action    string `json:"action"`
	Owner     string `json:"owner"`
	TxID      string `json:"txId"`
	Timestamp string `json:"timestamp"`
}

// OrgSetup contains organization's config to interact with the network
type OrgSetup struct {
	OrgName      string
	MSPID        string
	CertPath     string
	KeyPath      string
	TLSCertPath  string
	PeerEndpoint string
	GatewayPeer  string
	Gateway      client.Gateway
}

var (
	orgSetup OrgSetup
)

// initializeGateway initializes the Fabric Gateway connection
func initializeGateway() error {
	// Set up the organization configuration based on test-network structure
	cryptoPath := "/home/myindo/workspace/myindo/hyperledger-go/fabric-samples/test-network/organizations/peerOrganizations/org1.example.com"

	orgSetup = OrgSetup{
		OrgName:      "Org1",
		MSPID:        "Org1MSP",
		CertPath:     cryptoPath + "/users/Admin@org1.example.com/msp/signcerts/Admin@org1.example.com-cert.pem",
		KeyPath:      cryptoPath + "/users/Admin@org1.example.com/msp/keystore/",
		TLSCertPath:  cryptoPath + "/peers/peer0.org1.example.com/tls/ca.crt",
		PeerEndpoint: "localhost:7051",
		GatewayPeer:  "peer0.org1.example.com",
	}

	log.Printf("Initializing connection for %s...", orgSetup.OrgName)

	clientConnection := orgSetup.newGrpcConnection()
	id := orgSetup.newIdentity()
	sign := orgSetup.newSign()

	gateway, err := client.Connect(
		id,
		client.WithSign(sign),
		client.WithClientConnection(clientConnection),
		// Default timeouts are sufficient for most operations
	)
	if err != nil {
		return fmt.Errorf("failed to connect to gateway: %v", err)
	}
	orgSetup.Gateway = *gateway

	log.Println("Gateway initialization complete")
	return nil
}

// newGrpcConnection creates a gRPC connection to the Gateway server
func (setup OrgSetup) newGrpcConnection() *grpc.ClientConn {
	certificate, err := loadCertificate(setup.TLSCertPath)
	if err != nil {
		log.Panicf("failed to load TLS certificate: %v", err)
	}

	certPool := x509.NewCertPool()
	certPool.AddCert(certificate)
	transportCredentials := credentials.NewClientTLSFromCert(certPool, setup.GatewayPeer)

	connection, err := grpc.Dial(setup.PeerEndpoint, grpc.WithTransportCredentials(transportCredentials))
	if err != nil {
		log.Panicf("failed to create gRPC connection: %v", err)
	}

	return connection
}

// newIdentity creates a client identity for this Gateway connection using an X.509 certificate
func (setup OrgSetup) newIdentity() *identity.X509Identity {
	certificate, err := loadCertificate(setup.CertPath)
	if err != nil {
		log.Panicf("failed to load certificate: %v", err)
	}

	id, err := identity.NewX509Identity(setup.MSPID, certificate)
	if err != nil {
		log.Panicf("failed to create identity: %v", err)
	}

	return id
}

// newSign creates a function that generates a digital signature from a message digest using a private key
func (setup OrgSetup) newSign() identity.Sign {
	files, err := ioutil.ReadDir(setup.KeyPath)
	if err != nil {
		log.Panicf("failed to read private key directory: %v", err)
	}

	privateKeyPEM, err := ioutil.ReadFile(path.Join(setup.KeyPath, files[0].Name()))
	if err != nil {
		log.Panicf("failed to read private key file: %v", err)
	}

	privateKey, err := identity.PrivateKeyFromPEM(privateKeyPEM)
	if err != nil {
		log.Panicf("failed to parse private key: %v", err)
	}

	sign, err := identity.NewPrivateKeySign(privateKey)
	if err != nil {
		log.Panicf("failed to create sign function: %v", err)
	}

	return sign
}

func loadCertificate(filename string) (*x509.Certificate, error) {
	certificatePEM, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to read certificate file: %w", err)
	}
	return identity.CertificateFromPEM(certificatePEM)
}

// evaluateTransaction evaluates a transaction (query)
func evaluateTransaction(function string, args ...string) ([]byte, error) {
	network := orgSetup.Gateway.GetNetwork("mychannel")
	contract := network.GetContract("custom-chaincode")

	return contract.EvaluateTransaction(function, args...)
}

// submitTransaction submits a transaction (invoke)
func submitTransaction(function string, args ...string) ([]byte, error) {
	network := orgSetup.Gateway.GetNetwork("mychannel")
	contract := network.GetContract("custom-chaincode")

	txn_proposal, err := contract.NewProposal(function, client.WithArguments(args...))
	if err != nil {
		return nil, fmt.Errorf("failed to create transaction proposal: %v", err)
	}

	txn_endorsed, err := txn_proposal.Endorse()
	if err != nil {
		return nil, fmt.Errorf("failed to endorse transaction: %v", err)
	}

	_, err = txn_endorsed.Submit()
	if err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %v", err)
	}

	result := txn_endorsed.Result()
	return result, nil
}

// initLedger initializes ledger with sample data
func initLedger(c *gin.Context) {
	_, err := submitTransaction("InitLedger")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Ledger initialized successfully"})
}

// createAsset creates a new asset
func createAsset(c *gin.Context) {
	var req CreateAssetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := submitTransaction("CreateAsset", req.ID, req.Color, fmt.Sprintf("%d", req.Size), req.Owner, fmt.Sprintf("%d", req.AppraisedValue))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Asset created successfully", "id": req.ID})
}

// readAsset reads an asset by ID
func readAsset(c *gin.Context) {
	id := c.Param("id")
	output, err := evaluateTransaction("ReadAsset", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	var asset Asset
	err = json.Unmarshal(output, &asset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, asset)
}

// updateAsset updates an existing asset
func updateAsset(c *gin.Context) {
	id := c.Param("id")
	var req UpdateAssetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := submitTransaction("UpdateAsset", id, req.Color, fmt.Sprintf("%d", req.Size), req.Owner, fmt.Sprintf("%d", req.AppraisedValue))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Asset updated successfully"})
}

// deleteAsset deletes an asset by ID
func deleteAsset(c *gin.Context) {
	id := c.Param("id")
	_, err := submitTransaction("DeleteAsset", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Asset deleted successfully"})
}

// transferAsset transfers an asset to a new owner
func transferAsset(c *gin.Context) {
	id := c.Param("id")
	var req TransferAssetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := submitTransaction("TransferAsset", id, req.NewOwner)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Asset transferred successfully"})
}

// getAllAssets retrieves all assets
func getAllAssets(c *gin.Context) {
	output, err := evaluateTransaction("GetAllAssets")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	var assets []Asset
	err = json.Unmarshal(output, &assets)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, assets)
}

// getAssetsByOwner retrieves assets by owner
func getAssetsByOwner(c *gin.Context) {
	owner := c.Param("owner")
	output, err := evaluateTransaction("GetAssetsByOwner", owner)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	var assets []Asset
	err = json.Unmarshal(output, &assets)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, assets)
}

// getAssetHistory retrieves the history of an asset
func getAssetHistory(c *gin.Context) {
	assetID := c.Param("id")
	output, err := evaluateTransaction("GetAssetHistory", assetID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	var history []AssetHistory
	err = json.Unmarshal(output, &history)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, history)
}

// getAssetCount retrieves the total count of assets
func getAssetCount(c *gin.Context) {
	output, err := evaluateTransaction("GetAssetCount")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	var count int
	err = json.Unmarshal(output, &count)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"count": count})
}

func main() {
	// Initialize Fabric Gateway
	err := initializeGateway()
	if err != nil {
		log.Fatalf("Failed to initialize Fabric Gateway: %v", err)
	}
	defer orgSetup.Gateway.Close()

	// Initialize Gin router
	r := gin.Default()

	// CORS middleware
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// API routes
	api := r.Group("/api/v1")
	{
		// Ledger operations
		api.POST("/ledger/init", initLedger)

		// Asset operations
		api.POST("/assets", createAsset)
		api.GET("/assets", getAllAssets)
		api.GET("/assets/count", getAssetCount)
		api.GET("/assets/:id", readAsset)
		api.GET("/assets/:id/history", getAssetHistory)
		api.PUT("/assets/:id", updateAsset)
		api.DELETE("/assets/:id", deleteAsset)
		api.POST("/assets/:id/transfer", transferAsset)

		// Owner-specific operations
		api.GET("/owners/:owner/assets", getAssetsByOwner)
	}

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "fabric-api",
			"sdk":     "fabric-gateway",
		})
	})

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	port = ":" + port
	log.Printf("Starting Fabric Gateway-based API server on port %s", port)
	log.Fatal(r.Run(port))
}
