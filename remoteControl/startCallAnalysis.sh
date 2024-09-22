#!/bin/bash

source 'functions.sh'

function getOpenTelemetryCalls {
	currentDay=$(date +%Y-%m-%d)
	for service in teastore-registry-1 teastore-persistence-1 teastore-auth-1 teastore-recommender-1 teastore-image-1 teastore-webui-1
	do
		echo -n "$service "
		curl -X GET "localhost:9200/zipkin-span-"$currentDay"/_count" -H 'Content-Type: application/json' -d '{
		  "query": {
		    "term": {
		      "localEndpoint.serviceName": '$service'
		    }
		  }
		}'
	done
}

function getMapping {
	if [ -z "$1" ] || [ "$1" == "KIEKER_ASPECTJ_TEXT" ]
	then
		docker run --rm -v $(pwd)/kieker-results:/kieker-results -v $(pwd):/remoteControl fedora:latest bash -c "cd remoteControl && ./getMapping.sh"
	fi
	
	if [ "$1" == "OPENTELEMETRY_ZIPKIN_MEMORY" ]
	then
		getOpenTelemetryCalls
	fi
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

echo "It is assumed you've build already: ./mvnw clean package && cd tools/ && ./build_docker.sh && cd .. (If you didn't, please abort and start freshly)"

TEASTORE_RUNNER_IP=$1

if [ "$2" ]
then
	case "$2" in
		"KIEKER_ASPECTJ_TEXT")
			# Do nothing, since this is the default configuration
			;;
		"OPENTELEMETRY_ZIPKIN_MEMORY")
			cd ..
			removeAllInstrumentation
			instrumentForOpenTelemetry $TEASTORE_RUNNER_IP "$2"
			;;
		*) echo "Configuration $2 not supported for call analysis; Exiting"; exit 1;;
	esac
fi

./mvnw clean package -DskipTests &> build.txt

maven_exit_status=$?
if [ $maven_exit_status -eq 1 ]; then
    echo "Maven build did not succeed - cancelling"
    exit 1
fi

cd tools && ./build_docker.sh >> ../build.txt && cd ..

for iteration in {1..30}
do

	echo "Starting Iteration $iteration"
	startAllContainers $TEASTORE_RUNNER_IP
	
	./waitForStartup.sh $IP
	stopTeaStore
	sleep 5
	sync
	
	echo "Collecting data..."
	getMapping $2 &> loops_0_$iteration.txt

	for LOOPS in 10 100 1000 10000
	do
		echo "Starting loops: $loops"
		echo "Replacing loops by $LOOPS"
		sed -i 's/<stringProp name="LoopController.loops">[^<]*<\/stringProp>/<stringProp name="LoopController.loops">'$LOOPS'<\/stringProp>/' ../examples/jmeter/teastore_browse_nogui.jmx
	
		echo "Replacing host name by $TEASTORE_RUNNER_IP"
		sed -i '/>hostname/{n;s/.*/\            <stringProp name="Argument.value"\>'$TEASTORE_RUNNER_IP'\<\/stringProp\>/}' ../examples/jmeter/teastore_browse_nogui.jmx
		
		startAllContainers $TEASTORE_RUNNER_IP
		./waitForStartup.sh $IP
		
		echo "Startup beendet"
		sleep 60
		
		java -jar $JMETER_HOME/bin/ApacheJMeter.jar \
			-t ../examples/jmeter/teastore_browse_nogui.jmx -n \
			-l jmeter_"$LOOPS"_$iteration.csv
	
		stopTeaStore
		sleep 5
		sync
		
		echo "Collecting data..."
		getMapping $2 &> loops_"$LOOPS"_$iteration.txt
	done
done
