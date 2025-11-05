package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing an Asset
type SmartContract struct {
	contractapi.Contract
}

// Asset describes the basic details of an asset
type Asset struct {
	ID             string `json:"ID"`
	Color          string `json:"color"`
	Size           int    `json:"size"`
	Owner          string `json:"owner"`
	AppraisedValue int    `json:"appraisedValue"`
	CreatedAt      string `json:"createdAt"`
	UpdatedAt      string `json:"updatedAt"`
}

// AssetHistory tracks the history of an asset
type AssetHistory struct {
	AssetID   string `json:"assetId"`
	Action    string `json:"action"`
	Owner     string `json:"owner"`
	TxID      string `json:"txId"`
	Timestamp string `json:"timestamp"`
}

// InitLedger adds a base set of assets to the ledger
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	assets := []Asset{
		{ID: "asset1", Color: "blue", Size: 5, Owner: "Tomoko", AppraisedValue: 300},
		{ID: "asset2", Color: "red", Size: 5, Owner: "Brad", AppraisedValue: 400},
		{ID: "asset3", Color: "green", Size: 10, Owner: "Jin Soo", AppraisedValue: 500},
		{ID: "asset4", Color: "yellow", Size: 10, Owner: "Max", AppraisedValue: 600},
		{ID: "asset5", Color: "black", Size: 15, Owner: "Adriana", AppraisedValue: 700},
		{ID: "asset6", Color: "white", Size: 15, Owner: "Michel", AppraisedValue: 800},
		{ID: "asset7", Color: "purple", Size: 20, Owner: "Aarav", AppraisedValue: 900},
		{ID: "asset8", Color: "orange", Size: 20, Owner: "Lili", AppraisedValue: 1000},
		{ID: "asset9", Color: "pink", Size: 25, Owner: "Yu", AppraisedValue: 1100},
		{ID: "asset10", Color: "brown", Size: 25, Owner: "Karim", AppraisedValue: 1200},
	}

	for _, asset := range assets {
		assetJSON, err := json.Marshal(asset)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(asset.ID, assetJSON)
		if err != nil {
			return fmt.Errorf("failed to put to world state. %v", err)
		}

		// Record creation history
		history := AssetHistory{
			AssetID:   asset.ID,
			Action:    "CREATE",
			Owner:     asset.Owner,
			TxID:      ctx.GetStub().GetTxID(),
			Timestamp: time.Now().Format(time.RFC3339),
		}
		historyJSON, _ := json.Marshal(history)
		ctx.GetStub().PutState(fmt.Sprintf("HISTORY_%s_%s", asset.ID, ctx.GetStub().GetTxID()), historyJSON)
	}

	return nil
}

// CreateAsset issues a new asset to the world state with given details
func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, color string, size int, owner string, appraisedValue int) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("the asset %s already exists", id)
	}

	asset := Asset{
		ID:             id,
		Color:          color,
		Size:           size,
		Owner:          owner,
		AppraisedValue: appraisedValue,
		CreatedAt:      time.Now().Format(time.RFC3339),
		UpdatedAt:      time.Now().Format(time.RFC3339),
	}
	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, assetJSON)
}

// ReadAsset returns the asset stored in the world state with given id
func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if assetJSON == nil {
		return nil, fmt.Errorf("the asset %s does not exist", id)
	}

	var asset Asset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err
	}

	return &asset, nil
}

// UpdateAsset updates an existing asset in the world state with provided parameters
func (s *SmartContract) UpdateAsset(ctx contractapi.TransactionContextInterface, id string, color string, size int, owner string, appraisedValue int) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("the asset %s does not exist", id)
	}

	// Get existing asset to record history
	existingAsset, err := s.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	// Overwrite the original asset with the new asset
	asset := Asset{
		ID:             id,
		Color:          color,
		Size:           size,
		Owner:          owner,
		AppraisedValue: appraisedValue,
		CreatedAt:      existingAsset.CreatedAt, // Preserve original creation time
		UpdatedAt:      time.Now().Format(time.RFC3339),
	}
	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(id, assetJSON)
	if err != nil {
		return err
	}

	// Record update history
	history := AssetHistory{
		AssetID:   id,
		Action:    "UPDATE",
		Owner:     owner,
		TxID:      ctx.GetStub().GetTxID(),
		Timestamp: time.Now().Format(time.RFC3339),
	}
	historyJSON, _ := json.Marshal(history)
	ctx.GetStub().PutState(fmt.Sprintf("HISTORY_%s_%s", id, ctx.GetStub().GetTxID()), historyJSON)

	return nil
}

// DeleteAsset deletes an given asset from the world state
func (s *SmartContract) DeleteAsset(ctx contractapi.TransactionContextInterface, id string) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("the asset %s does not exist", id)
	}

	return ctx.GetStub().DelState(id)
}

// AssetExists returns true when asset with given ID exists in world state
func (s *SmartContract) AssetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}

	return assetJSON != nil, nil
}

// TransferAsset updates the owner field of asset with given id in world state
func (s *SmartContract) TransferAsset(ctx contractapi.TransactionContextInterface, id string, newOwner string) error {
	asset, err := s.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	asset.Owner = newOwner
	asset.UpdatedAt = time.Now().Format(time.RFC3339)

	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(id, assetJSON)
	if err != nil {
		return err
	}

	// Record transfer history
	history := AssetHistory{
		AssetID:   id,
		Action:    "TRANSFER",
		Owner:     newOwner,
		TxID:      ctx.GetStub().GetTxID(),
		Timestamp: time.Now().Format(time.RFC3339),
	}
	historyJSON, _ := json.Marshal(history)
	ctx.GetStub().PutState(fmt.Sprintf("HISTORY_%s_%s", id, ctx.GetStub().GetTxID()), historyJSON)

	return nil
}

// GetAllAssets returns all assets found in world state
func (s *SmartContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
	// range query with empty string for startKey and endKey does an open-ended query of all assets in the chaincode namespace.
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var assets []*Asset
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var asset Asset
		err = json.Unmarshal(queryResponse.Value, &asset)
		if err != nil {
			return nil, err
		}
		assets = append(assets, &asset)
	}

	return assets, nil
}

// GetAssetsByOwner returns all assets owned by a specific owner
func (s *SmartContract) GetAssetsByOwner(ctx contractapi.TransactionContextInterface, owner string) ([]*Asset, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var assets []*Asset
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var asset Asset
		err = json.Unmarshal(queryResponse.Value, &asset)
		if err != nil {
			continue // Skip non-asset records
		}

		if asset.Owner == owner {
			assets = append(assets, &asset)
		}
	}

	return assets, nil
}

// GetAssetHistory returns the history of changes for a specific asset
func (s *SmartContract) GetAssetHistory(ctx contractapi.TransactionContextInterface, assetID string) ([]AssetHistory, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var history []AssetHistory
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		// Check if this is a history record for the requested asset
		key := queryResponse.Key
		if len(key) > 8 && key[:8] == "HISTORY_" {
			var hist AssetHistory
			err = json.Unmarshal(queryResponse.Value, &hist)
			if err != nil {
				continue
			}

			if hist.AssetID == assetID {
				history = append(history, hist)
			}
		}
	}

	return history, nil
}

// GetAssetCount returns the total number of assets in the ledger
func (s *SmartContract) GetAssetCount(ctx contractapi.TransactionContextInterface) (int, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return 0, err
	}
	defer resultsIterator.Close()

	count := 0
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return 0, err
		}

		// Skip history records and only count assets
		key := queryResponse.Key
		if len(key) < 8 || key[:8] != "HISTORY_" {
			var asset Asset
			err = json.Unmarshal(queryResponse.Value, &asset)
			if err == nil {
				count++
			}
		}
	}

	return count, nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		log.Panicf("Error creating chaincode: %v", err)
	}

	if err := chaincode.Start(); err != nil {
		log.Panicf("Error starting chaincode: %v", err)
	}
}
