package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"

	"github.com/gin-gonic/gin"
)

// Asset represents structure of an asset
type Asset struct {
	ID             string `json:"ID"`
	Color          string `json:"color"`
	Size           int    `json:"size"`
	Owner          string `json:"owner"`
	AppraisedValue int    `json:"appraisedValue"`
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

// executeChaincode executes a chaincode command using docker exec
func executeChaincode(command string, args ...string) (string, error) {
	// Build peer chaincode command with all arguments
	chaincodeArgs := []string{"chaincode", command}
	chaincodeArgs = append(chaincodeArgs, args...)

	// Build full docker exec command
	bashScript := "export CORE_PEER_TLS_ENABLED=true && " +
		"export CORE_PEER_LOCALMSPID=Org1MSP && " +
		"export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem && " +
		"export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && " +
		"export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && " +
		"peer " + strings.Join(chaincodeArgs, " ")

	allArgs := []string{"exec", "cli", "bash", "-c", bashScript}

	cmd := exec.Command("docker", allArgs...)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("command failed: %s, output: %s", err.Error(), string(output))
	}

	// Extract JSON from output if it exists
	outputStr := string(output)
	if strings.Contains(outputStr, "{") {
		start := strings.Index(outputStr, "{")
		end := strings.LastIndex(outputStr, "}")
		if start != -1 && end != -1 && end > start {
			return outputStr[start : end+1], nil
		}
	}

	return outputStr, nil
}

// initLedger initializes ledger with sample data
func initLedger(c *gin.Context) {
	output, err := executeChaincode("invoke", "-o", "orderer.example.com:7050",
		"--ordererTLSHostnameOverride", "orderer.example.com",
		"--tls", "--cafile", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem",
		"-C", "mychannel", "-n", "basic", "-c", "\""+args+"\"",
		"--peerAddresses", "peer0.org1.example.com:7051",
		"--tlsRootCertFiles", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem",
		"--peerAddresses", "peer0.org2.example.com:9051",
		"--tlsRootCertFiles", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem")

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Ledger initialized successfully", "output": output})
}

// createAsset creates a new asset
func createAsset(c *gin.Context) {
	var req CreateAssetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	args := fmt.Sprintf(`{"Args":["CreateAsset","%s","%s","%d","%s","%d"]}`,
		req.ID, req.Color, req.Size, req.Owner, req.AppraisedValue)

	output, err := executeChaincode("invoke", "-o", "orderer.example.com:7050",
		"--ordererTLSHostnameOverride", "orderer.example.com",
		"--tls", "--cafile", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem",
		"-C", "mychannel", "-n", "basic", "-c", "\""+args+"\"",
		"--peerAddresses", "peer0.org1.example.com:7051",
		"--tlsRootCertFiles", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem")

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Asset created successfully", "id": req.ID, "output": output})
}

// readAsset reads an asset by ID
func readAsset(c *gin.Context) {
	id := c.Param("id")
	args := fmt.Sprintf(`{"Args":["ReadAsset","%s"]}`, id)
	output, err := executeChaincode("query", "-C", "mychannel", "-n", "basic", "-c", "\""+args+"\"")

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	var asset Asset
	err = json.Unmarshal([]byte(output), &asset)
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

	args := fmt.Sprintf(`{"Args":["UpdateAsset","%s","%s","%d","%s","%d"]}`,
		id, req.Color, req.Size, req.Owner, req.AppraisedValue)

	output, err := executeChaincode("invoke", "-o", "orderer.example.com:7050",
		"--ordererTLSHostnameOverride", "orderer.example.com",
		"--tls", "--cafile", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem",
		"-C", "mychannel", "-n", "basic", "-c", "\""+args+"\"",
		"--peerAddresses", "peer0.org1.example.com:7051",
		"--tlsRootCertFiles", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem")

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Asset updated successfully", "output": output})
}

// deleteAsset deletes an asset by ID
func deleteAsset(c *gin.Context) {
	id := c.Param("id")
	args := fmt.Sprintf(`{"Args":["DeleteAsset","%s"]}`, id)
	output, err := executeChaincode("invoke", "-o", "orderer.example.com:7050",
		"--ordererTLSHostnameOverride", "orderer.example.com",
		"--tls", "--cafile", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem",
		"-C", "mychannel", "-n", "basic", "-c", "\""+args+"\"",
		"--peerAddresses", "peer0.org1.example.com:7051",
		"--tlsRootCertFiles", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem")

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Asset deleted successfully", "output": output})
}

// transferAsset transfers an asset to a new owner
func transferAsset(c *gin.Context) {
	id := c.Param("id")
	var req TransferAssetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	args := fmt.Sprintf(`{"Args":["TransferAsset","%s","%s"]}`, id, req.NewOwner)
	output, err := executeChaincode("invoke", "-o", "orderer.example.com:7050",
		"--ordererTLSHostnameOverride", "orderer.example.com",
		"--tls", "--cafile", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem",
		"-C", "mychannel", "-n", "basic", "-c", "\""+args+"\"",
		"--peerAddresses", "peer0.org1.example.com:7051",
		"--tlsRootCertFiles", "/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem")

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Asset transferred successfully", "output": output})
}

// getAllAssets retrieves all assets
func getAllAssets(c *gin.Context) {
	args := `{"Args":["GetAllAssets"]}`
	output, err := executeChaincode("query", "-C", "mychannel", "-n", "basic", "-c", "\""+args+"\"")

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	var assets []Asset
	err = json.Unmarshal([]byte(output), &assets)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, assets)
}

func main() {
	// Check if CLI container is running
	cmd := exec.Command("docker", "ps", "--filter", "name=cli", "--format", "{{.Names}}")
	output, err := cmd.Output()
	if err != nil || strings.TrimSpace(string(output)) != "cli" {
		log.Fatal("CLI container is not running. Please start the Fabric network first.")
	}

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
		api.GET("/assets/:id", readAsset)
		api.PUT("/assets/:id", updateAsset)
		api.DELETE("/assets/:id", deleteAsset)
		api.POST("/assets/:id/transfer", transferAsset)
	}

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "fabric-api",
		})
	})

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	port = ":" + port
	log.Printf("Starting server on port %s", port)
	log.Fatal(r.Run(port))
}
