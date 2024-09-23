#!/bin/bash

if [ $# -lt 1 ]
then
	echo "Please provide IP as parameter! (Parameters: ./startContainer.sh $REGISTRY_IP $TEASTORE_CONFIG_NAME $CONTAINER_ID $AGENT_IP"
	exit 1
fi

if [ $# -gt 3 ]
then
	CONTAINER_ID=$3
	AGENT_IP=$4
	if [[ $AGENT_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
	then
		echo "IP $agent_ip will be used for the current host"
	else
		echo "IP $agent_ip not valid; exiting"
		exit 1
	fi
else
	CONTAINER_ID="1"
fi

REGISTRY_IP=$1
BASE_DIR=`pwd`
MY_FOLDER="$BASE_DIR/kieker-results/"

set -e

source executionControl/functions.sh

echo "Building current version..."

./mvnw clean package -DskipTests &> build.txt

maven_exit_status=$?
if [ $maven_exit_status -eq 1 ]; then
    echo "Maven build did not succeed - cancelling"
    exit 1
fi

cd tools && ./build_docker.sh >> ../build.txt && cd ..

if [ -d $MY_FOLDER ] && [ ! -z "$( ls -A $MY_FOLDER )" ]
then
	export DEPLOY=0
	docker run --rm -v $MY_FOLDER:/kieker-results alpine sh -c "rm -rf /kieker-results/*"
fi

mkdir -p $MY_FOLDER

echo "Creating docker containers..."

startContainers $CONTAINER_ID $REGISTRY_IP $AGENT_IP

recommender_id=$(docker ps | grep "recommender" | awk '{print $1}')
waitForContainerStartup $recommender_id 'org.apache.catalina.startup.Catalina.start Server startup in '

# the database will only be on the main server
database_id=$(docker ps | grep "teastore-db" | awk '{print $1}')
if [ ! -z "$database_id" ]
then	
	waitForContainerStartup $database_id 'port: 3306'
fi
