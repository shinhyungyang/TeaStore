function createDebugOutput {
	index=1
	folder="debug_$index"

	while [ -d "$folder" ]
	do
		((index++))
		folder="debug_$index"
	done

	mkdir $folder
	docker ps &> $folder/dockerps.txt
	for container in $(cat $folder/dockerps.txt | awk '{print $1}')
	do
		docker logs $container &> $folder/$container.txt
	done
}

function waitForContainerStartup {
	containerName=$1
	textToWaitFor=$2
	
	echo "Waiting for $containerName to be ready"
	attempt=0
	while [ $attempt -le 300 ]; do
	    attempt=$(( $attempt + 1 ))
	    echo "Waiting for $containerName to be up (attempt: $attempt)..."
	    result=$(docker logs $containerName 2>&1)
	    if grep -q "$textToWaitFor" <<< $result ; then
	      echo "$containerName is up!"
	      break
	    fi
	    sleep 5
	done
}
function waitForPodStartup {
	podName=$1
	textToWaitFor=$2
	
	echo "Waiting for $podName to be ready"
	attempt=0
	while [ $attempt -le 300 ]; do
      attempt=$(( $attempt + 1 ))
	    echo "Waiting for $podName to be up (attempt: $attempt)..."
      result=$(kubectl logs $podName 2>&1)
	    if grep -q "$textToWaitFor" <<< $result ; then
	      echo "$podName is up!"
	      break
	    fi
	    sleep 5
	done
}

function waitForFullstartup {
	server=$1
	port=$2
	attempt=0
	while [ $attempt -le 50 ]; do
		# Check the status using curl and grep
		if ! curl --max-time 5 -s http://$server:$port/tools.descartes.teastore.webui/status 2>&1 | grep -q "Offline"
		then
			echo "Service is online. Exiting..."
			break
		fi
		echo "Services are still partially offline. Checking again in 5 seconds (attempt: $attempt)..."
		sleep 5
		((attempt++))
	done
	
	if curl --max-time 5 -s http://$server:$port/tools.descartes.teastore.webui/status 2>&1 | grep -q "Offline"
	then
		echo "Service is still offline after 50 attempts. Exiting..."
		createDebugOutput
		return 1
	fi
	return 0
}

function startContainers {
	CONTAINER_ID=$1
	REGISTRY_IP=$2
	AGENT_IP=$3 # Currently not used, for the future when multiple servers are fully supported...
	
	if [ $CONTAINER_ID == "1" ]
	then
		registry='descartesresearch/'
		docker run --hostname=teastore-db-$CONTAINER_ID \
			-p 3306:3306 -d ${registry}teastore-db
		docker run --hostname=teastore-registry-$CONTAINER_ID \
			-e "HOST_NAME=$REGISTRY_IP" -e "SERVICE_PORT=10000" -p 10000:8080 -d ${registry}teastore-registry 
		docker run --hostname=teastore-persistence-$CONTAINER_ID \
		-v $MY_FOLDER/teastore-persistence:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$REGISTRY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$REGISTRY_IP" -e "SERVICE_PORT=1111" -e "DB_HOST=$REGISTRY_IP" -e "DB_PORT=3306" -p 1111:8080 -d ${registry}teastore-persistence
	docker run --hostname=teastore-auth-$CONTAINER_ID \
		-v $MY_FOLDER/teastore-auth:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$REGISTRY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$REGISTRY_IP" -e "SERVICE_PORT=2222" -p 2222:8080 -d ${registry}teastore-auth
	docker run --hostname=teastore-recommender-$CONTAINER_ID \
		-v $MY_FOLDER/teastore-recommender:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$REGISTRY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$REGISTRY_IP" -e "SERVICE_PORT=3333" -p 3333:8080 -d ${registry}teastore-recommender
	docker run --hostname=teastore-image-$CONTAINER_ID \
		-v $MY_FOLDER/teastore-image:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$REGISTRY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$REGISTRY_IP" -e "SERVICE_PORT=4444" -p 4444:8080 -d ${registry}teastore-image
	docker run --hostname=teastore-webui-$CONTAINER_ID \
		-v $MY_FOLDER/teastore-webui:/kieker/logs/ -e "LOG_TO_FILE=true" -e "REGISTRY_HOST=$REGISTRY_IP" -e "REGISTRY_PORT=10000" -e "HOST_NAME=$REGISTRY_IP" -e "SERVICE_PORT=8080" -p 8080:8080 -d ${registry}teastore-webui
	fi
}
