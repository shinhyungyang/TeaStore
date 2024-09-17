#!/bin/bash

source 'functions.sh'

function getMapping {
	docker run --rm -v $(pwd)/kieker-results:/kieker-results -v $(pwd):/remoteControl fedora:latest bash -c "cd remoteControl && ./getMapping.sh"
}

function stopTeaStore {
	docker ps | grep teastore | awk '{print $1}' | xargs docker stop $1
	docker ps -a | grep teastore | awk '{print $1}' | xargs docker rm -f $1
}

function startAllContainers {
	MY_IP=$1
	container_id=1
	
	MY_FOLDER=$(pwd)/kieker-results/
	if [ -d $MY_FOLDER ] && [ ! -z "$( ls -A $MY_FOLDER )" ]
	then
		docker run --rm -v $MY_FOLDER:/kieker-results alpine sh -c "rm -rf /kieker-results/*"
	fi
	echo "MY_FOLDER: $MY_FOLDER IP: $MY_IP"
	
	docker run --hostname=teastore-db-$container_id \
		-p 3306:3306 -d teastore-db
	docker run --hostname=teastore-registry-$container_id \
		-e "HOST_NAME=$MY_IP" -e "SERVICE_PORT=10000" -p 10000:8080 -d teastore-registry 
	docker run --hostname=teastore-persistence-$container_id \
		-v $MY_FOLDER/teastore-persistence:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$MY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$MY_IP" -e "SERVICE_PORT=1111" -e "DB_HOST=$MY_IP" -e "DB_PORT=3306" -p 1111:8080 -d teastore-persistence
	docker run --hostname=teastore-auth-$container_id \
		-v $MY_FOLDER/teastore-auth:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$MY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$MY_IP" -e "SERVICE_PORT=2222" -p 2222:8080 -d teastore-auth
	docker run --hostname=teastore-recommender-$container_id \
		-v $MY_FOLDER/teastore-recommender:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$MY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$MY_IP" -e "SERVICE_PORT=3333" -p 3333:8080 -d teastore-recommender
	docker run --hostname=teastore-image-$container_id \
		-v $MY_FOLDER/teastore-image:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$MY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$MY_IP" -e "SERVICE_PORT=4444" -p 4444:8080 -d teastore-image
	docker run --hostname=teastore-webui-$container_id \
		-v $MY_FOLDER/teastore-webui:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$MY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$MY_IP" -e "SERVICE_PORT=8080" -p 8080:8080 -d teastore-webui
	
	recommender_id=$(docker ps | grep "recommender" | awk '{print $1}')
	waitForContainerStartup $recommender_id 'org.apache.catalina.startup.Catalina.start Server startup in '
	
	database_id=$(docker ps | grep "teastore-db" | awk '{print $1}')
	if [ ! -z "$database_id" ]
	then	
		waitForContainerStartup $database_id 'port: 3306'
	fi
	echo "Waiting for initial startup..."
	sleep 5
}

if [ $# -lt 1 ]
then
	echo "Please provide IP as parameter!"
	exit 1
fi

TEASTORE_RUNNER_IP=$1

for iteration in {1..5}
do

	echo "Starting Iteration $iteration"
	startAllContainers $TEASTORE_RUNNER_IP
	
	./waitForStartup.sh $IP
	stopTeaStore
	
	echo "Collecting data..."
	getMapping &> loops_0_$iteration.txt

	for LOOPS in 100 1000
	do
		echo "Starting loops: $loops"
		echo "Replacing loops by $LOOPS"
		sed -i 's/<stringProp name="LoopController.loops">[^<]*<\/stringProp>/<stringProp name="LoopController.loops">100<\/stringProp>/' ../examples/jmeter/teastore_browse_nogui.jmx
	
		echo "Replacing host name by $TEASTORE_RUNNER_IP"
		sed -i '/>hostname/{n;s/.*/\            <stringProp name="Argument.value"\>'$TEASTORE_RUNNER_IP'\<\/stringProp\>/}' ../examples/jmeter/teastore_browse_nogui.jmx
		
		startAllContainers $TEASTORE_RUNNER_IP
		./waitForStartup.sh $IP
		
		echo "Startup beendet"
		sleep 10
		
		java -jar $JMETER_HOME/bin/ApacheJMeter.jar -t ../examples/jmeter/teastore_browse_nogui.jmx -n
	
		stopTeaStore
		
		
		echo "Collecting data..."
		getMapping &> loops_"$LOOPS"_$iteration.txt
	done
done
