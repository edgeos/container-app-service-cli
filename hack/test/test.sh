#!/bin/bash

# Copyright (c) 2017 by General Electric Company. All rights reserved.

# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

set -e

# Vars
ALPINE_BASE="registry.gear.ge.com/predix_edge/alpine-amd64:3.4"
CAPPSD_REPO=git@github.build.ge.com:PredixEdgeOS/container-app-service
CAPPSD_DIR=_container-app-service
EXIT_CODE=0

# Clone latest cappsd
if [ ! -d ${CAPPSD_DIR} ]; then 
	git clone ${CAPPSD_REPO} ${CAPPSD_DIR}
	rm -rf  ${CAPPSD_REPO}/.git
	# Requires two builds to work
	make --debug -C ${CAPPSD_DIR} build || make --debug  -C ${CAPPSD_DIR} build 
fi

# Catch any failure and kill Cappsd container
{

# Launch Cappsd
CAPPSD_CONTAINER_ID=$(docker run -d \
	-v ${PWD}/${CAPPSD_DIR}/test_artifacts/:/test_artifacts \
	-v ${PWD}/${CAPPSD_DIR}/ecs.json:/ecs.json \
	-v ${PWD}/${CAPPSD_DIR}/bin/amd64/cappsd:/cappsd \
	-v ${PWD}/bin/amd64/cappsd-cli:/cappsd-cli \
	-v /var/run/docker.sock:/var/run/docker.sock \
	${ALPINE_BASE} \
		/bin/sh -c 'while true; do echo "keep alive"; sleep 60; done')


echo "++++++++++++++++++++++++++++++++++++++"
echo "Socket  Suite"
echo "++++++++++++++++++++++++++++++++++++++"

# Test: No Socket, via Ping
NOSOCK_CMD="/cappsd-cli -endpoint ping"
docker exec -t ${CAPPSD_CONTAINER_ID} ${NOSOCK_CMD}
if [ $? -ne 18 ]; then
	echo -e "\nNo Socket -- Failure"
	EXIT_CODE=1
else
	echo -e "\nNo Socket -- Success"
fi

echo ""
echo "======================================"
echo ""

# Start Cappsd

CAPPSD_CMD_1="mkdir -p /mnt/data"
CAPPSD_CMD_2="/cappsd -config /"
docker exec -t ${CAPPSD_CONTAINER_ID} ${CAPPSD_CMD_1}
$(docker exec -t ${CAPPSD_CONTAINER_ID} ${CAPPSD_CMD_2}) &
echo $?
if [ $? -ne 0 ]; then
	echo "Starting Cappsd -- Failed"
	EXIT_CODE=1
	exit 1
else
	echo "Starting Cappsd -- Success"
fi 

echo "++++++++++++++++++++++++++++++++++++++"
echo "Bad Input Suite"
echo "++++++++++++++++++++++++++++++++++++++"

# Test: No Arguments
NOARG_CMD="/cappsd-cli"
docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${NOARG_CMD}"
if [ $? -ne 11 ]; then 
	echo "No Argument -- Failure"
	EXIT_CODE=1
else
	echo "No Argument -- Success"
fi
echo "--------------------------------------"

# Test: No Endpoint
NOEP_CMD="/cappsd-cli -tar_file /test_artifacts/helloapp.tar.gz"
docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${NOEP_CMD}"
if [ $? -ne 12 ]; then
	echo "No Endpoint -- Failure"
	EXIT_CODE=1
else
	echo "No Endpoint -- Success"
fi
echo "--------------------------------------"

# Test: Unknown Endpoint
UEP_CMD="/cappsd-cli -endpoint unknown"
docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${UEP_CMD}"
if [ $? -ne 13 ]; then 
	echo "Unknown Endpoint -- Failure"
	EXIT_CODE=1
else
	echo "Unknown Endpoint -- Success"
fi
echo "--------------------------------------"

# Test: Canno Open Tar File
TF_CMD="/cappsd-cli -endpoint deploy -tar_file abcd"
docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${TF_CMD}"
if [ $? -ne 14 ]; then
	echo "Failed Tar File Open -- Failed"
	EXIT_CODE=1
else
	echo "Failed Tar File Open -- Success"
fi
echo "--------------------------------------"


echo ""
echo "======================================"
echo ""
echo "++++++++++++++++++++++++++++++++++++++"
echo "API Test Suite"
echo "++++++++++++++++++++++++++++++++++++++"

# Test Ping
PING_CMD="/cappsd-cli -endpoint ping"
docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${PING_CMD}" 
if [ $? -ne 0 ]; then 
	echo "Ping -- Failed"
	EXIT_CODE=1 
else
	echo "Ping -- Success"
fi
echo "--------------------------------------"


# Test Deploy
TAR_FILE_PATH="/test_artifacts/helloapp.tar.gz"
DEPLOY_CMD="/cappsd-cli -endpoint deploy -tar_file ${TAR_FILE_PATH}"
DEPLOY_OUTPUT=$(docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${DEPLOY_CMD}")
DEPLOY_RET_STATUS=$?
echo ${DEPLOY_OUTPUT}
echo ""
if [ $? -ne 0 ]; then
	echo "Deploy -- Failed"
	EXIT_CODE=1
	DEPLOY_SUCCESS=false
else
	echo "Deploy -- Success"
	DEPLOY_SUCCESS=true
	APPLICATION_ID=$(echo ${DEPLOY_OUTPUT} | grep -oe 'uuid":"[0-9,a-f,\-]*' | sed 's/uuid":"//')
fi
echo "--------------------------------------"

# Test Applications
APPS_CMD="/cappsd-cli -endpoint applications"
if [ $DEPLOY_SUCCESS = true ]; then
	docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${APPS_CMD}"
	if [ $? -ne 0 ]; then
		echo "Applications -- Failed"
		EXIT_CODE=1
	else
		echo "Applications -- Success"
	fi
else
	echo "Applications -- Skipping"
fi
echo "--------------------------------------"

# Test Application
APP_CMD="/cappsd-cli -endpoint application -id ${APPLICATION_ID}"
APP_SUCCESS=false
if [ $DEPLOY_SUCCESS = true ]; then
	APP_DETAILS=$(docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${APP_CMD}")
	APP_STATUS=$?
	echo ${APP_DETAILS}
	echo ""
	if [ ${APP_STATUS} -ne 0 ]; then
		echo "Application -- Failed"
		EXIT_CODE=1
	else
		echo "Application -- Success"
		APP_SUCCESS=true
		CONTAINER_NAMES=$(echo ${APP_DETAILS} | grep -o '"name":"[0-9,a-z,A-Z,_,\-]*"' | sed 's/"name":"//g' | tr '"' ' ')
	fi
else
	echo "Application -- Skipping"
fi
echo "--------------------------------------"

# Test Status
STAT_CMD="/cappsd-cli -endpoint status -id ${APPLICATION_ID}"
if [ $DEPLOY_SUCCESS = true ]; then
	docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${STAT_CMD}"
	if [ $? -ne 0 ]; then
		echo "Status -- Failed"
		EXIT_CODE=1
	else
		echo "Status -- Success"
	fi
else
	echo "Status -- Skipping"
fi
echo "--------------------------------------"

# Test Stop
STOP_CMD="/cappsd-cli -endpoint stop -id ${APPLICATION_ID}"
if [ $DEPLOY_SUCCESS = true ]; then
	docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${STOP_CMD}"
	if [ $? -ne 0 ]; then
		echo "Stop -- Failed"
		EXIT_CODE=1
	else
		echo "Stop -- Success"
	fi
else
	echo "Stop -- Skipping"
fi
echo "--------------------------------------"

# Test Start
START_CMD="/cappsd-cli -endpoint start -id ${APPLICATION_ID}"
if [ $DEPLOY_SUCCESS = true ]; then
	docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${START_CMD}"
	if [ $? -ne 0 ]; then
		echo "Start -- Failed"
		EXIT_CODE=1
	else
		echo "Start -- Success"
	fi
else
	echo "Start -- Skipping"
fi
echo "--------------------------------------"

# Test Restart
sleep 5
RESTART_CMD="/cappsd-cli -endpoint restart -id ${APPLICATION_ID}"
if [ $DEPLOY_SUCCESS = true ]; then
	docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${RESTART_CMD}"
	if [ $? -ne 0 ]; then
		echo "Restart -- Failed"
		EXIT_CODE=1
	else
		echo "Restart -- Success"
	fi
else
	echo "Restart -- Skipping"
fi
echo "--------------------------------------"

# Test Purge
PURGE_CMD="/cappsd-cli -endpoint purge -id ${APPLICATION_ID}"
PURGE_SUCCESS=false
if [ $DEPLOY_SUCCESS = true ]; then	
	docker exec -t ${CAPPSD_CONTAINER_ID} /bin/sh -c "${PURGE_CMD}"
	if [ $? -ne 0 ]; then
		echo "Purge -- Failed"
		EXIT_CODE=1
	else
		echo "Purge -- Success"
		PURGE_SUCCESS=true
	fi
	if [ ${PURGE_SUCCESS} = false ]; then
		#Attempt cleanup
		if [ ${APP_SUCCESS} = true ]; then
			echo "Purge failed, attempting cleanup"
			echo $CONTAINER_NAMES | xargs docker rm -f 
		else
			echo "WARNING: could not automatically clean up containers"
		fi
	fi

else
	echo "Purge -- Skipping"
fi
echo "--------------------------------------"


} || {
# Set non-zero exit code
echo "Unexpected error"
EXIT_CODE=2
} 



# Kill Cappsd container 
docker rm -f ${CAPPSD_CONTAINER_ID} 
docker network prune -f
# Exit with code
exit ${EXIT_CODE}
