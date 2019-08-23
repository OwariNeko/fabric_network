!/bin/bash

Copyright IBM Corp All Rights Reserved

SPDX-License-Identifier: Apache-2.0


set -e
source utils.sh

if [ "$1" == "" ]; then
    echo "Usage: ./add_org2_orderer_to_consenter_list system-channel | channel1"
    exit 1
else
    CHANNEL=$1
    ORDERER=$2
fi

WORKING_DIR=downloads/${CHANNEL}_step
mkdir -p $WORKING_DIR
echo "Create $WORKING_DIR folder.."
docker exec cli mkdir -p $WORKING_DIR

export FLAG=$(if [ "$(uname -s)" == "Linux" ]; then echo "-w 0"; else echo "-b 0"; fi)
TLS_FILE=$PWD/crypto-config/ordererOrganizations/example.com/orderers/$ORDERER/tls/server.crt
echo "{\"client_tls_cert\":\"$(cat $TLS_FILE | base64 $FLAG)\",\"host\":\"$ORDERER\",\"port\":7050,\"server_tls_cert\":\"$(cat $TLS_FILE | base64 $FLAG)\"}" > $PWD/$WORKING_DIR/newconsenter.json

docker cp $PWD/$WORKING_DIR/newconsenter.json cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/$WORKING_DIR

retrieve_current_config $WORKING_DIR $CHANNEL  cli $ORDERER

echo "Add new orderer.org.example.com to list of Consenters and prepare protobuf update.."
docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'jq ".channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters += [$(cat $WORKING_DIR/newconsenter.json)]" $WORKING_DIR/current_config.json > $WORKING_DIR/modified_config.json'

prepare_unsigned_modified_config $WORKING_DIR $CHANNEL  cli $ORDERER


echo "Org1MSP signs and sends update.."
    docker exec -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp" -e "CORE_PEER_ADDRESS=orderer.example.com:7050" -e "CORE_PEER_LOCALMSPID=OrdererMSP" -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt" -e "ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" -e "WORKING_DIR=$WORKING_DIR" -e "ORDERER=orderer.example.com:7050" -e "CHANNEL=$CHANNEL" -e "ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" cli sh -c 'peer channel update -f $WORKING_DIR/config_update_in_envelope.pb -o $ORDERER --tls --cafile $ORDERER_CA -c $CHANNEL'

retrieve_updated_config $WORKING_DIR $CHANNEL  cli $ORDERER

echo "Copying updated config block.."
docker cp cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/$WORKING_DIR/updated_config.pb $PWD/channel-artifacts/latest_config_$ORDERER.block

# docker exec -e "WORKING_DIR=$WORKING_DIR" -e "CHANNEL=$CHANNEL" cli sh -c 'cp $WORKING_DIR/updated_config.pb /channel-artifacts/latest_config_$CHANNEL.block'

echo "Done!!"


