#!/bin/bash

function retrieve_current_config()
{
    WORKING_DIR=$1
    CHANNEL=$2
    CONTAINER=$3
    ORDERER="orderer.example.com:7050"

    echo "Retrieve $CHANNEL latest config block.."
    docker exec -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp" -e "CORE_PEER_ADDRESS=orderer.example.com:7050" -e "CORE_PEER_LOCALMSPID=OrdererMSP" -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt" -e "ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" -e "WORKING_DIR=$WORKING_DIR" -e "ORDERER=$ORDERER" -e "CHANNEL=$CHANNEL" -e "ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" $CONTAINER sh -c 'peer channel fetch config $WORKING_DIR/current_config.pb -o $ORDERER --tls --cafile $ORDERER_CA -c $CHANNEL'

    echo "Convert the config block into JSON format.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" $CONTAINER sh -c 'configtxlator proto_decode --input $WORKING_DIR/current_config.pb --type common.Block --output $WORKING_DIR/current_config_block.json'

    echo "Stripping headers.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" $CONTAINER sh -c 'jq .data.data[0].payload.data.config $WORKING_DIR/current_config_block.json > $WORKING_DIR/current_config.json'
}

function retrieve_updated_config()
{
    WORKING_DIR=$1
    CHANNEL=$2
    CONTAINER=$3
    ORDERER="orderer.example.com:7050"

    echo "Retrieve $CHANNEL latest config block.."
    docker exec -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp" -e "CORE_PEER_ADDRESS=orderer.example.com:7050" -e "CORE_PEER_LOCALMSPID=OrdererMSP" -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt" -e "ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" -e "WORKING_DIR=$WORKING_DIR" -e "ORDERER=$ORDERER" -e "CHANNEL=$CHANNEL" -e"ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" $CONTAINER sh -c 'peer channel fetch config $WORKING_DIR/updated_config.pb -o $ORDERER --tls --cafile $ORDERER_CA -c $CHANNEL'

    echo "Convert the config block into JSON format.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" $CONTAINER sh -c 'configtxlator proto_decode --input $WORKING_DIR/updated_config.pb --type common.Block --output $WORKING_DIR/updated_config_block.json'

    echo "Stripping headers.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" $CONTAINER sh -c 'jq .data.data[0].payload.data.config $WORKING_DIR/updated_config_block.json > $WORKING_DIR/updated_config.json'
}

function prepare_unsigned_modified_config()
{
    WORKING_DIR=$1
    CHANNEL=$2
    CONTAINER=$3

    echo "Preparing unsigned protobuf update.."

    echo "Step 1/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" $CONTAINER sh -c 'configtxlator proto_encode --input $WORKING_DIR/current_config.json --type common.Config --output $WORKING_DIR/current_config.pb'

    echo "Step 2/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" $CONTAINER sh -c 'configtxlator proto_encode --input $WORKING_DIR/modified_config.json --type common.Config --output $WORKING_DIR/modified_config.pb'

    echo "Step 3/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" -e "CHANNEL=$CHANNEL" $CONTAINER sh -c 'configtxlator compute_update --channel_id $CHANNEL --original $WORKING_DIR/current_config.pb --updated $WORKING_DIR/modified_config.pb --output $WORKING_DIR/config_update.pb'

    echo "Step 4/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" $CONTAINER sh -c 'configtxlator proto_decode --input $WORKING_DIR/config_update.pb --type common.ConfigUpdate  --output $WORKING_DIR/config_update.json'

    echo "Step 5/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" -e "CHANNEL=$CHANNEL" $CONTAINER sh -c 'echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"$CHANNEL\", \"type\":2}},\"data\":{\"config_update\":"$(cat $WORKING_DIR/config_update.json)"}}}" | jq . > $WORKING_DIR/config_update_in_envelope.json'

    echo "Step 6/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" $CONTAINER sh -c 'configtxlator proto_encode --input $WORKING_DIR/config_update_in_envelope.json --type common.Envelope --output $WORKING_DIR/config_update_in_envelope.pb'

}