#!/bin/bash

function VERIFY_RESULT {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
		BROADCAST "FATAL ERROR - EXITING"
		echo
		exit 1
	fi
}

function BROADCAST {
	local MESSAGE=$1

	echo
	echo "======================================================================="
	echo "   > ${MESSAGE}"
	echo "======================================================================="
	echo
}

function BROADCAST_RESULT {
	local MESSAGE=$1

	echo "-----------------------------------------------------------------------"
	echo "  ${MESSAGE}"
	echo "-----------------------------------------------------------------------"
}

function SET_PEER_ENV {
	local PEER_NAME=${1}
	local LOG_LEVEL=${2:-DEBUG}

	export CORE_LOGGING_LEVEL=${LOG_LEVEL}
	export CORE_PEER_LOCALMSPID="Org1MSP"
	export CORE_PEER_TLS_ENABLED=false
	export CORE_PEER_TLS_ROOTCERT_FILE=/data/tls/ca_root.pem
	export CORE_PEER_MSPCONFIGPATH=/data/adminOrg1MSP
	export CORE_PEER_ADDRESS=${PEER_NAME}.${PEER_DOMAIN}:7051

	if [ "${LOG_LEVEL}" = "DEBUG"  ]; then
		BROADCAST "SETTING PEER ENV"
		env | grep CORE
	fi
}

function CREATE_CHANNEL {
	local CHANNEL_NAME=$1

	BROADCAST "CREATING CHANNEL: ${CHANNEL_NAME}"

	$PEER_BIN channel create -o ${ORDERER_HOST}:7050 -c ${CHANNEL_NAME} \
	-f ${CHANNEL_BASEDIR}/${CHANNEL_NAME}.tx >&log.txt
# --tls ${CORE_PEER_TLS_ENABLED} --cafile ${ORDERER_CA_CERT} 

	res=$?
	cat log.txt
	# DISABLE FOR NOW, WITH KAFKA ENABLED YOU GET AN ERROR BUT IT ACTUALLY WORKS
	VERIFY_RESULT $res "Channel creation failed"
	BROADCAST_RESULT "Channel ${CHANNEL_NAME} was created successfully"
	sleep 2
}

function JOIN_CHANNEL {
	local CHANNEL_NAME=$1

	BROADCAST "${CORE_PEER_ADDRESS} JOINING CHANNEL: ${CHANNEL_NAME}"

	$PEER_BIN channel join -b ${CHANNEL_NAME}.block  >&log.txt

	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		BROADCAST_RESULT "${CORE_PEER_ADDRESS} failed to JOIN. Retrying.."
		sleep 1
		JOIN_CHANNEL $1
	else
		COUNTER=0
	fi

	VERIFY_RESULT $res "After $MAX_RETRY attempts, ${CORE_PEER_ADDRESS} has failed to Join the Channel"
	sleep 1
}

function PACKAGE_CHAINCODE {
	local CC_NAME=$1
	local CC_VERSION=$2
	local CC_PATH=$3

	BROADCAST "${CORE_PEER_ADDRESS} PACKAGING CHAINCODE: ${CC_NAME}"

	# signing package does not seem to install. disable for now: -s -S -i "AND('Org1.admin')"
	$PEER_BIN chaincode package \
	-n ${CC_NAME} -v ${CC_VERSION} \
	-p ${CC_PATH} \
	${CC_NAME}_v${CC_VERSION}.out >&log.txt

	res=$?
	cat log.txt
	VERIFY_RESULT $res "Chaincode installation on remote peer ${CORE_PEER_ADDRESS} has Failed"
	BROADCAST_RESULT "Chaincode is installed on remote peer ${CORE_PEER_ADDRESS}"
	sleep 1

}

function UPDATE_ANCHORPEERS {
	local CHANNEL_NAME=$1
	local CHANNEL_TX=$2

	$PEER_BIN channel update -o ${ORDERER_HOST}:7050 \
	-c ${CHANNEL_NAME} -f ${CHANNEL_BASEDIR}/${CHANNEL_TX}.tx >&log.txt

	# -c ${CHANNEL_NAME} -f ${CHANNEL_BASEDIR}/${CHANNEL_TX}.tx \
	# --tls $CORE_PEER_TLS_ENABLED --cafile ${ORDERER_CA_CERT} >&log.txt

	res=$?
	cat log.txt
	VERIFY_RESULT $res "Update Anchor Peers on remote peer ${CORE_PEER_ADDRESS} has Failed"
	BROADCAST_RESULT "Update Anchor Peers Successful"
	sleep 1

}


function INSTALL_CHAINCODE_PACKAGE {
	local CC_PKG=$1

	BROADCAST "${CORE_PEER_ADDRESS} INSTALLING CHAINCODE PKG: ${CC_PKG}"

	$PEER_BIN chaincode install \
	${CC_PKG} >&log.txt

	res=$?
	cat log.txt
	VERIFY_RESULT $res "Chaincode PKG installation on remote peer ${CORE_PEER_ADDRESS} has Failed"
	BROADCAST_RESULT "Chaincode PKG is installed on remote peer ${CORE_PEER_ADDRESS}"
	sleep 1

}

function INSTALL_CHAINCODE {
	local CC_NAME=$1
	local CC_VERSION=$2
	local CC_PATH=$3

	BROADCAST "${CORE_PEER_ADDRESS} INSTALLING CHAINCODE: ${CC_NAME}"

	$PEER_BIN chaincode install \
	-n ${CC_NAME} -v ${CC_VERSION} \
	-p ${CC_PATH} >&log.txt

	res=$?
	cat log.txt
	VERIFY_RESULT $res "Chaincode installation on remote peer ${CORE_PEER_ADDRESS} has Failed"
	BROADCAST_RESULT "Chaincode is installed on remote peer ${CORE_PEER_ADDRESS}"
	sleep 1

}

function INIT_CHAINCODE {
	local CHANNEL_NAME=$1
	local CC_NAME=$2
	local CC_VERSION=$3
	local CC_POLCIY=$4
	local CC_CONSTRUCTOR=$5

	BROADCAST "${CORE_PEER_ADDRESS} INIT CHAINCODE: ${CC_NAME}"

	$PEER_BIN chaincode instantiate -o ${ORDERER_HOST}:7050 \
	-C ${CHANNEL_NAME} \
	-n ${CC_NAME} -v ${CC_VERSION} -c "${CC_CONSTRUCTOR}" -P "${CC_POLCIY}" >&log.txt
	# --tls ${CORE_PEER_TLS_ENABLED} --cafile ${ORDERER_CA_CERT} -C ${CHANNEL_NAME} \

	res=$?
	cat log.txt
	VERIFY_RESULT $res "Chaincode instantiation on ${CORE_PEER_ADDRES} on channel '${CHANNEL_NAME}' failed"
	BROADCAST_RESULT "Chaincode Instantiation on ${CORE_PEER_ADDRES} on channel '$CHANNEL_NAME' is successful"
	sleep 1

}

function INVOKE_CHAINCODE {
	local CHANNEL_NAME=$1
	local CC_NAME=$2
	local CC_VERSION=$3
	local CC_CONSTRUCTOR=$4

	BROADCAST "${CORE_PEER_ADDRESS} INVOKE CHAINCODE: ${CC_NAME}"

	$PEER_BIN chaincode invoke -o ${ORDERER_HOST}:7050 \
	-C ${CHANNEL_NAME} \
	-n ${CC_NAME} -v ${CC_VERSION} -c "${CC_CONSTRUCTOR}" >&log.txt
	# --tls ${CORE_PEER_TLS_ENABLED} --cafile ${ORDERER_CA_CERT} -C ${CHANNEL_NAME} \

	res=$?
	cat log.txt
	VERIFY_RESULT $res "Chaincode invoke on ${CORE_PEER_ADDRES} on channel '${CHANNEL_NAME}' failed"
	BROADCAST_RESULT "Chaincode invoke on ${CORE_PEER_ADDRES} on channel '$CHANNEL_NAME' is successful"
	sleep 0.5

}

function QUERY_CHAINCODE {
	local CHANNEL_NAME=$1
	local CC_NAME=$2
	local CC_VERSION=$3
	local CC_QUERY=$4

	BROADCAST "${CORE_PEER_ADDRESS} QUERY CHAINCODE: ${CC_NAME}"

	$PEER_BIN chaincode query \
	-C ${CHANNEL_NAME} \
	-n ${CC_NAME} -v ${CC_VERSION} -c "${CC_QUERY}" >&log.txt

	# --tls ${CORE_PEER_TLS_ENABLED} -C ${CHANNEL_NAME} \

	res=$?
	cat log.txt
	VERIFY_RESULT $res "Chaincode Queried on ${CORE_PEER_ADDRES} on channel '${CHANNEL_NAME}' failed"
	BROADCAST_RESULT "Chaincode Queried on ${CORE_PEER_ADDRES} on channel '${CHANNEL_NAME}' is successful"
	#sleep 1

}

function FETCH_BLOCK {
	local CHANNEL_NAME=$1
	local BLOCK_TO_FETCH=$2

	BROADCAST "FETCHING BLOCK ${BLOCK_TO_FETCH} FROM CHANNEL ${CHANNEL_NAME}"

	# when using TLS the block is always called true
	$PEER_BIN channel fetch ${BLOCK_TO_FETCH} \
	--channelID ${CHANNEL_NAME} \
	-o ${ORDERER_HOST}:7050 #\
	# --tls ${CORE_PEER_TLS_ENABLED} \
	# --cafile ${ORDERER_CA_CERT}

	VERIFY_RESULT $? "Failed to fetch block"
	mv true ${CHANNEL_NAME}_${BLOCK_TO_FETCH}.block
	BROADCAST_RESULT "The block was fetched successfully"

}

function VIEW_BLOCK {
	local BLOCK_FILE=$1
	local PROFILE=$2
	local CHANNEL=$3

	BROADCAST "VIEWING BLOCK ${BLOCK_FILE}"

	FABRIC_CFG_PATH=/data \
	configtxgen -profile ${PROFILE} \
	-channelID ${CHANNEL} \
	-inspectBlock ${BLOCK_FILE}

}

function LIST_CHANNELS {

	BROADCAST "LISTING JOINED CHANNELS FOR: ${CORE_PEER_ADDRESS}"

	$PEER_BIN channel list

}

################################################################################
# START TEST CODE
################################################################################


cd /data/channel-artifacts
/data/create_channel_tx.sh


PEER_BIN=/usr/local/bin/peer
CHANNEL_BASEDIR=/data/channel-artifacts

# ENV SPECS --------------------------------------------------------------------
ORDERER_HOST="orderer0.fabric.linuxctl.com"
ORDERER_CA_CERT=/data/tls/ca_root.pem

PEER_PREFIX=""
PEER_DOMAIN="fabric.linuxctl.com"
PEER_MSP_ID="Org1MSP"

COUNTER=0
MAX_RETRY=5


# CREATE CHANNELS
SET_PEER_ENV peer0; CREATE_CHANNEL testchannel

# JOIN CHANNELS
for i in peer0 peer1; do
	SET_PEER_ENV ${i}
	JOIN_CHANNEL testchannel
done

# LIST JOINED CHANNELS
for i in peer0 peer1; do
	SET_PEER_ENV ${i}; LIST_CHANNELS
done

# UPDATE ANCHOR PEERS
SET_PEER_ENV peer0; UPDATE_ANCHORPEERS testchannel org1anchors

# PACKAGE AND SIGN CHAINCODE (testing for now)
SET_PEER_ENV peer0; PACKAGE_CHAINCODE ex02 "1.0" github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02

# INSTALL CHAINCODE
for i in peer0 peer1; do
	SET_PEER_ENV ${i}
	# Install from pkg doesnt seem to work when signed...
	INSTALL_CHAINCODE_PACKAGE $(pwd)/ex02_v1.0.out
	#INSTALL_CHAINCODE ex02 "1.0" github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02
done

# INIT CHAINCODE
SET_PEER_ENV peer0
INIT_CHAINCODE testchannel ex02 "1.0" "OR ('Org1MSP.member')" '{"Args":["init","a","1000","b","1000"]}'

# wait a bit before query/invoke
sleep 3

# WARM UP CC
SET_PEER_ENV peer1; QUERY_CHAINCODE testchannel ex02 "1.0" '{"Args":["query","a"]}'

# DO SOME RANDOM INVOKES AND QUERIES
BROADCAST "DOING RANDOM INVOKES AND QUERIES NOW..."
sleep 3

for i in {1..20}; do
	# INVOKE on random peer
	n=$(( $RANDOM % 2 ))
	SET_PEER_ENV peer${n} CRITICAL
	INVOKE_CHAINCODE testchannel ex02 "1.0" '{"Args":["invoke","a","b","10"]}'

	# QUERY on random peer
	n=$(( $RANDOM % 2 ))
	SET_PEER_ENV peer${n} CRITICAL
	QUERY_CHAINCODE testchannel ex02 "1.0" '{"Args":["query","a"]}'
done

# FETCH AND VIEW CONFIG BLOCK FOR FUN
FETCH_BLOCK testchannel config
VIEW_BLOCK testchannel_config.block linuxctlChannel testchannel

BROADCAST "SCRIPT HAS COMPLETED!"
