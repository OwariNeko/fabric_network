#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

set -e
source utils.sh

if [ "$1" == "" ]; then
    echo "Usage: ./add_org2_orderer_to_consenter_list system-channel | channel1"
    exit 1
else
    CHANNEL=$1
    ORDERER=$2

fi

WORKING_DIR=/downloads/${CHANNEL}_step4

echo "Create $WORKING_DIR folder.."
docker exec cli mkdir -p $WORKING_DIR

retrieve_current_config $WORKING_DIR $CHANNEL cli

echo "Add new orderer.example.com to list of addresses.."
docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'jq ".channel_group.values.OrdererAddresses.value.addresses += [\"${ORDERER}:7050\"]" $WORKING_DIR/current_config.json > $WORKING_DIR/modified_config.json'

prepare_unsigned_modified_config $WORKING_DIR $CHANNEL cli


echo "Org1MSP signs and sends update.."
docker exec -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp" -e "CORE_PEER_ADDRESS=orderer.example.com:7050" -e "CORE_PEER_LOCALMSPID=OrdererMSP" -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt" -e "ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" -e "WORKING_DIR=$WORKING_DIR" -e "ORDERER=orderer.example.com:7050" -e "CHANNEL=$CHANNEL" -e "ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" cli sh -c 'peer channel update -f $WORKING_DIR/config_update_in_envelope.pb -o $ORDERER --tls --cafile $ORDERER_CA -c $CHANNEL'

retrieve_updated_config $WORKING_DIR $CHANNEL cli

echo "Done!!"