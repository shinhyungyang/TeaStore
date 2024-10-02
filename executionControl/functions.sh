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

function waitForFullstartup {
	server=$1
	attempt=0
	while [ $attempt -le 50 ]; do
		# Check the status using curl and grep
		if ! curl --max-time 5 -s http://$server:8080/tools.descartes.teastore.webui/status 2>&1 | grep -q "Offline"
		then
			echo "Service is online. Exiting..."
			break
		fi
		echo "Services are still partially offline. Checking again in 5 seconds (attempt: $attempt)..."
		sleep 5
		((attempt++))
	done
	
	if curl --max-time 5 -s http://$server:8080/tools.descartes.teastore.webui/status 2>&1 | grep -q "Offline"
	then
		echo "Service is still offline after 50 attempts. Exiting..."
		createDebugOutput
		return 1
	fi
	return 0
}

function resetInstrumentationFiles {
	git checkout -- utilities/tools.descartes.teastore.dockerbase/Dockerfile
	git checkout -- utilities/tools.descartes.teastore.dockerbase/kieker-2.0.0-aspectj.jar
	git checkout -- utilities/tools.descartes.teastore.dockerbase/start.sh

	git checkout -- utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties

	git checkout -- utilities/tools.descartes.teastore.registryclient/src/main/java/tools/descartes/teastore/registryclient/rest/*
	for file in $(find . -name "pom.xml"); do git checkout -- $file; done
}

function removeAllInstrumentation {
	sed -i 's/-javaagent:\/kieker\/agent\/agent\.jar//g' utilities/tools.descartes.teastore.dockerbase/start.sh
	for pomFile in interfaces/tools.descartes.teastore.entities/pom.xml  utilities/tools.descartes.teastore.registryclient/pom.xml #TODO Should be removed for all files, but currently only works here...
	do
		awk '{
		    if (line_count > 0) { line_count--; next; }
		    if ($0 ~ /<groupId>net.kieker-monitoring<\/groupId>/) {
			line_count = 4;
			next;
		    }
		    print;
		}' $pomFile &> temp.xml
		mv temp.xml $pomFile
	done
	
	sed -i '/<module>\.\/utilities\/tools\.descartes\.teastore\.kieker\.probes<\/module>/d; /<module>\.\/utilities\/tools\.descartes\.teastore\.kieker\.rabbitmq<\/module>/d'  pom.xml
	
	for pomFile in services/tools.descartes.teastore.auth/pom.xml services/tools.descartes.teastore.persistence/pom.xml  services/tools.descartes.teastore.recommender/pom.xml  services/tools.descartes.teastore.registry/pom.xml  services/tools.descartes.teastore.webui/pom.xml
	do
		awk '{
                    if (line_count > 0) { line_count--; next; }
                    if ($0 ~ /<artifactId>kieker.probes<\/artifactId>/) {
                        line_count = 4; prev="";
                        next;
                    } else {print prev;}
                    prev=$0;
                } END {print prev}' $pomFile &> temp.xml
                mv temp.xml $pomFile
       done
       
       for pomFile in services/tools.descartes.teastore.image/pom.xml # no space here
	do
		awk '{
                    if (line_count > 0) { line_count--; next; }
                    if ($0 ~ /<artifactId>kieker.probes<\/artifactId>/) {
                        line_count = 3; prev="";
                        next;
                    } else {print prev;}
                    prev=$0;
                } END {print prev}' $pomFile &> temp.xml
                mv temp.xml $pomFile
       done
       
       sed -i '/^COPY kieker-2.0.0-aspectj\.jar/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
       sed -i '/^COPY kieker\.monitoring\.properties/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
       sed -i '/^COPY aop\.xml/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
       rm utilities/tools.descartes.teastore.dockerbase/kieker-*
       cp no-instrumentation-sources/* utilities/tools.descartes.teastore.registryclient/src/main/java/tools/descartes/teastore/registryclient/rest/
}

function instrumentForOpenTelemetry {
	MY_IP=$1
	TYPE=$2

	if [ ! -f utilities/tools.descartes.teastore.dockerbase/opentelemetry-javaagent.jar ]
	then
		curl -L -O https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar
		mv opentelemetry-javaagent.jar utilities/tools.descartes.teastore.dockerbase/opentelemetry-javaagent.jar
	fi
	
	git checkout -- utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY kieker-2.0.0-aspectj\.jar/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY kieker\.monitoring\.properties/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY aop\.xml/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	
	sed -i '/^EXPOSE 8080/i COPY opentelemetry-javaagent.jar \/opentelemetry\/agent\/agent.jar' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^EXPOSE 8080/i COPY otel-config.properties \/opentelemetry\/agent\/otel-config.properties' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	git checkout -- utilities/tools.descartes.teastore.dockerbase/start.sh
	
	OTEL_INCLUDES="tools.descartes.teastore.auth.rest.AuthCartRest[addProductToCart];tools.descartes.teastore.auth.rest.AuthUserActionsRest[isLoggedIn,login,logout];tools.descartes.teastore.auth.security.BCryptProvider[checkPassword];tools.descartes.teastore.auth.security.ConstantKeyProvider[getKey];tools.descartes.teastore.auth.security.RandomSessionIdGenerator[getSessionId];tools.descartes.teastore.auth.security.ShaSecurityProvider[blobToString,getKeyProvider,getSha512,secure,validate];tools.descartes.teastore.image.ImageProvider[getImageFor,getProductImages,getWebUIImages,scaleAndRegisterImg,setImageDB,setStorage];tools.descartes.teastore.image.rest.ImageProviderEndpoint[getProductImages,getWebUIImages];tools.descartes.teastore.image.setup.SetupController[configureImageProvider,convertToIDs,createWorkingDir,deleteImages,deleteUnusedImages,deleteWorkingDir,detectCategoryImages,detectExistingImages,detectExistingImages,fetchCategories,fetchProductsForCategory,generateImages,generateImages,getPathToResource,getWorkingDir,isFirstImageProvider,matchCategoriesToImage,setupStorage,startup,waitForPersistence];tools.descartes.teastore.image.storage.DriveStorage[dataIsStorable,getIDLock,loadData,loadFromDisk,saveData];tools.descartes.teastore.persistence.domain.CategoryRepository[createEntity,getEntityClass];tools.descartes.teastore.persistence.domain.OrderItemRepository[createEntity,getEntityClass];tools.descartes.teastore.persistence.domain.OrderRepository[createEntity,getEntityClass,updateEntity];tools.descartes.teastore.persistence.domain.PersistenceCategory[getDescription,getId,getName,setDescription,setName,setCategory];tools.descartes.teastore.persistence.domain.PersistenceOrder[getAddress1,getAddress2,getAddressName,getCreditCardCompany,getCreditCardExpiryDate,getCreditCardExpiryLocalDate,getCreditCardNumber,getId,getOrderTime,getTime,getTotalPriceInCents,getUserId,setAddress1,setAddress2,setAddressName,setCreditCardCompany,setCreditCardExpiryDate,setCreditCardExpiryLocalDate,setCreditCardNumber,setOrderTime,setTime,setTotalPriceInCents,setUser,getId,getOrder,getOrderId,getProductId,getQuantity,getUnitPriceInCents,setOrder,setProduct,setQuantity,setUnitPriceInCents];tools.descartes.teastore.persistence.domain.PersistenceOrderItem[getId,getOrder,getOrderId,getProductId,getQuantity,getUnitPriceInCents,setOrder,setProduct,setQuantity,setUnitPriceInCents];tools.descartes.teastore.persistence.domain.PersistenceOrder[getAddress1,getAddress2,getAddressName,getCreditCardCompany,getCreditCardExpiryDate,getCreditCardExpiryLocalDate,getCreditCardNumber,getId,getOrderTime,getTime,getTotalPriceInCents,getUserId,setAddress1,setAddress2,setAddressName,setCreditCardCompany,setCreditCardExpiryDate,setCreditCardExpiryLocalDate,setCreditCardNumber,setOrderTime,setTime,setTotalPriceInCents,setUser,getId,getOrder,getOrderId,getProductId,getQuantity,getUnitPriceInCents,setOrder,setProduct,setQuantity,setUnitPriceInCents];tools.descartes.teastore.persistence.domain.PersistenceProduct[setProduct,getCategoryId,getDescription,getId,getListPriceInCents,getName,setCategory,setDescription,setListPriceInCents,setName];tools.descartes.teastore.persistence.domain.PersistenceUser[setUser,getEmail,getId,getPassword,getRealName,getUserName,setEmail,setPassword,setRealName,setUserName];tools.descartes.teastore.persistence.domain.ProductRepository[createEntity,getAllEntities,getEntityClass,getProductCount];tools.descartes.teastore.persistence.domain.UserRepository[createEntity,getEntityClass,getUserByName];tools.descartes.teastore.persistence.rest.CategoryEndpoint[findEntityById,listAllEntities];tools.descartes.teastore.persistence.rest.OrderEndpoint[listAllEntities];tools.descartes.teastore.persistence.rest.OrderItemEndpoint[listAllEntities];tools.descartes.teastore.persistence.rest.ProductEndpoint[countForCategory,findEntityById,listAllForCategory];tools.descartes.teastore.persistence.rest.UserEndpoint[findById];tools.descartes.teastore.recommender.algorithm.impl.cf.SlopeOneRecommender[buildDifferencesMatrices,calculateScoreForItem,execute,executePreprocessing,getUserVector];tools.descartes.teastore.recommender.algorithm.impl.pop.PopularityBasedRecommender[executePreprocessing];tools.descartes.teastore.recommender.algorithm.RecommenderSelector[getInstance,recommendProducts,train];tools.descartes.teastore.recommender.rest.RecommendEndpoint[recommend];tools.descartes.teastore.recommender.servlet.TrainingSynchronizer[filterForMaxtimeStamp,filterLists,getInstance,retrieveDataAndRetrain,setReady,toMillis,waitForPersistence];tools.descartes.teastore.registryclient.rest.LoadBalancedCRUDOperations[getEntities,getEntities,getEntity,getEntityWithProperties];tools.descartes.teastore.registryclient.rest.LoadBalancedImageOperations[getProductImage,getProductImage,getProductImages,getProductPreviewImages,getWebImage,getWebImages];tools.descartes.teastore.registryclient.rest.LoadBalancedRecommenderOperations[getRecommendations];tools.descartes.teastore.registryclient.rest.LoadBalancedStoreOperations[addProductToCart,isLoggedIn,login,logout];tools.descartes.teastore.webui.servlet.CartActionServlet[handleGETRequest];tools.descartes.teastore.webui.servlet.CartServlet[handleGETRequest];tools.descartes.teastore.webui.servlet.CategoryServlet[createNavigation,handleGETRequest];tools.descartes.teastore.webui.servlet.IndexServlet[handleGETRequest];tools.descartes.teastore.webui.servlet.LoginActionServlet[handlePOSTRequest];tools.descartes.teastore.webui.servlet.ProductServlet[handleGETRequest]"
	
	case "$TYPE" in
		"OPENTELEMETRY_ZIPKIN_MEMORY")
		sed -i 's|-javaagent:/kieker/agent/agent.jar|-javaagent:/opentelemetry/agent/agent.jar -Dotel.javaagent.configuration-file=\/opentelemetry\/agent\/otel-config.properties -Dotel.resource.attributes=service.name=$(hostname)|g' utilities/tools.descartes.teastore.dockerbase/start.sh
		echo "otel.metrics.exporter=none" > utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.logs.exporter=none" >> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.traces.exporter=zipkin">> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.exporter.zipkin.endpoint=http://"$MY_IP":9411/api/v2/spans">> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.instrumentation.methods.include=$OTEL_INCLUDES">> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.javaagent.logging=true" >> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.javaagent.debug=true" >> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
			
		docker run -d -p 9411:9411 \
			--name zipkin \
			-e JAVA_OPTS="-Xms1g -Xmx4g" \
			openzipkin/zipkin
		;;
		"OPENTELEMETRY_ZIPKIN_ELASTIC")
		sed -i 's|-javaagent:/kieker/agent/agent.jar|-javaagent:/opentelemetry/agent/agent.jar -Dotel.javaagent.configuration-file=\/opentelemetry\/agent\/otel-config.properties -Dotel.resource.attributes=service.name=$(hostname)|g' utilities/tools.descartes.teastore.dockerbase/start.sh
		echo "otel.metrics.exporter=none" > utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.logs.exporter=none" >> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.traces.exporter=zipkin">> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.exporter.zipkin.endpoint=http://"$MY_IP":9411/api/v2/spans">> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.instrumentation.methods.include=$OTEL_INCLUDES">> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.javaagent.logging=true" >> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		echo "otel.javaagent.debug=true" >> utilities/tools.descartes.teastore.dockerbase/otel-config.properties
	
		docker run -d --name elasticsearch -p 9200:9200 -e discovery.type=single-node elasticsearch:7.10.1
		
		docker run -d -p 9411:9411 \
			--name zipkin \
			-e JAVA_OPTS="-Xms1g -Xmx2g" \
			-e STORAGE_TYPE=elasticsearch \
			-e ES_HOSTS=$MY_IP:9200 \
			-e ES_HTTP_LOGGING=BODY \
			openzipkin/zipkin

		# Elasticsearch zipkin works basically, but to get the dependencies, it is necessary to run the following:
		#docker run --env STORAGE_TYPE=elasticsearch --env ES_HOSTS=$MY_IP:9200 --env ES_NODES_WAN_ONLY=true openzipkin/zipkin-dependencies
		;;
		"OPENTELEMETRY_DEACTIVATED")
		sed -i 's|-javaagent:/kieker/agent/agent.jar|-javaagent:/opentelemetry/agent/agent.jar -Dotel.metrics.exporter=none -Dotel.traces.exporter=none|g' utilities/tools.descartes.teastore.dockerbase/start.sh
		echo "otel.metrics.exporter=none" > utilities/tools.descartes.teastore.dockerbase/otel-config.properties
		;;
		*) echo "Configuration $TYPE not found; Exiting"; exit 1;;
	esac
}

function downloadBytebuddyAgent {
	#export VERSION_PATH=`curl "https://oss.sonatype.org/service/local/repositories/snapshots/content/net/kieker-monitoring/kieker/" | grep '<resourceURI>' | sed 's/ *<resourceURI>//g' | sed 's/<\/resourceURI>//g' | grep '/$' | grep -v ".xml" | head -n 1`
	#export AGENT_PATH=`curl "${VERSION_PATH}" | grep 'bytebuddy.jar</resourceURI' | sort | sed 's/ *<resourceURI>//g' | sed 's/<\/resourceURI>//g' | tail -1`
	
	AGENT_PATH="https://repo1.maven.org/maven2/net/kieker-monitoring/kieker/2.0.0/kieker-2.0.0-bytebuddy.jar"
	
	AGENT_NAME=$(echo $AGENT_PATH | awk -F'/' '{print $NF}' | awk -F'-' '{print $1"-"$2"-"$5}')
	
	curl "${AGENT_PATH}" > kieker-bytebuddy-agent.jar
}

function instrumentForKiekerBytebuddy {
	if [ ! -f utilities/tools.descartes.teastore.dockerbase/kieker-2.0.0-bytebuddy.jar ]
	then
		downloadBytebuddyAgent
		# No the nicest solution, but for now, it stores the bytebuddy agent in a usable manner...
		mv kieker-bytebuddy-agent.jar utilities/tools.descartes.teastore.dockerbase/kieker-bytebuddy-agent.jar
	fi

	sed -i 's/kieker-2.0.0-aspectj/kieker-bytebuddy-agent/g' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY aop\.xml/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	
	echo 'echo "export KIEKER_SIGNATURES_INCLUDE=\"tools.descartes.teastore.*\"" >> /usr/local/tomcat/bin/setenv.sh' >> utilities/tools.descartes.teastore.dockerbase/start.sh
	echo 'echo "export KIEKER_SIGNATURES_EXCLUDE=\"tools.descartes.teastore.kieker.*;tools.descartes.teastore.entities.*;tools.descartes.teastore.rest.*;tools.descartes.teastore.registryclient.loadbalancers.*;tools.descartes.teastore.registryclient.RegistryClient;tools.descartes.teastore.auth.startup.AuthStartup;tools.descartes.teastore.registryclient.StartupCallbackTask;tools.descartes.teastore.registryclient.RegistryClientHeartbeatDaemon;tools.descartes.teastore.registryclient.Service;tools.descartes.teastore.registryclient.StartupCallback;tools.descartes.teastore.registryclient.rest.RestUtil;tools.descartes.teastore.persistence.daemons.*;tools.descartes.teastore.persistence.domain.converters.*;tools.descartes.teastore.persistence.repository.*;tools.descartes.teastore.persistence.servlet.*;tools.descartes.teastore.persistence.rest.DatabaseGenerationEndpoint;tools.descartes.teastore.recommender.servlet.IndexServlet;tools.descartes.teastore.recommender.servlet.RetrainDaemon;tools.descartes.teastore.recommender.servlet.RecommenderStartup;tools.descartes.teastore.recommender.rest.TrainEndPoint;tools.descartes.teastore.recommender.algorithm.impl.UseFallBackException;tools.descartes.teastore.recommender.algorithm.OrderItemSet;tools.descartes.teastore.recommender.algorithm.AbstractRecommender;tools.descartes.teastore.webui.startup.*;tools.descartes.teastore.webui.servlet.elhelper.*;tools.descartes.teastore.webui.servlet.AbstractUIServlet;tools.descartes.teastore.image.setup.CachingMode;tools.descartes.teastore.image.setup.CachingRule;tools.descartes.teastore.image.setup.CreatorFactory;tools.descartes.teastore.image.setup.CreatorRunner;tools.descartes.teastore.image.setup.ImageCreator;tools.descartes.teastore.image.setup.ImageIDFactory;tools.descartes.teastore.image.setup.ImageProviderStartup;tools.descartes.teastore.image.setup.StorageMode;tools.descartes.teastore.image.setup.StorageRule;tools.descartes.teastore.image.storage.rules.*;tools.descartes.teastore.image.cache.rules.*;tools.descartes.teastore.image.cache.entry.*;tools.descartes.teastore.image.ImageDB;tools.descartes.teastore.image.ImageDBKey;tools.descartes.teastore.image.ImageScaler;tools.descartes.teastore.image.StoreImage;tools.descartes.teastore.image.cache.AbstractQueueCache;tools.descartes.teastore.image.cache.AbstractTreeCache;tools.descartes.teastore.image.cache.FirstInFirstOut;tools.descartes.teastore.image.cache.IDataCache;tools.descartes.teastore.image.cache.LastInFirstOut;tools.descartes.teastore.image.cache.LeastFrequentlyUsed;tools.descartes.teastore.image.cache.LeastRecentlyUsed;tools.descartes.teastore.image.cache.MostRecentlyUsed;tools.descartes.teastore.image.cache.RandomReplacement;tools.descartes.teastore.registryclient.rest.HttpWrapper;tools.descartes.teastore.registryclient.rest.TrackingFilter;tools.descartes.teastore.registryclient.rest.ResponseWrapper;tools.descartes.teastore.registryclient.rest.CharResponseWrapper;tools.descartes.teastore.registryclient.rest.CharResponseWrapper.*;tools.descartes.teastore.registryclient.rest.CharResponseWrapper*;tools.descartes.teastore.image.cache.AbstractCache;tools.descartes.teastore.image.cache.AbstractCache.*;tools.descartes.teastore.registryclient.rest.NonBalancedCRUDOperations;tools.descartes.teastore.registryclient.util.RESTClient;tools.descartes.teastore.registryclient.util.RESTClient$1;tools.descartes.teastore.registryclient.util.AbstractCRUDEndpoint;tools.descartes.teastore.registryclient.tracing.Tracing\"" >> /usr/local/tomcat/bin/setenv.sh' >> utilities/tools.descartes.teastore.dockerbase/start.sh

}

function useBinaryWriterKieker {
	sed -i '/kieker.monitoring.writer=kieker.monitoring.writer.filesystem.FileWriter/a kieker.monitoring.writer.filesystem.FileWriter.logStreamHandler=kieker.monitoring.writer.filesystem.BinaryLogStreamHandler' utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties
}

function useTCPWriterKieker {
	HOSTNAME=$1
	sed -i "s/kieker.monitoring.writer=kieker.monitoring.writer.filesystem.FileWriter/#kieker.monitoring.writer=kieker.monitoring.writer.filesystem.FileWriter/g" utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties
	sed -i "s/#kieker.monitoring.writer=kieker.monitoring.writer.tcp.SingleSocketTcpWriter/kieker.monitoring.writer=kieker.monitoring.writer.tcp.SingleSocketTcpWriter/g" utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties
	sed -i "s/kieker.monitoring.writer.tcp.SingleSocketTcpWriter.hostname=localhost/kieker.monitoring.writer.tcp.SingleSocketTcpWriter.hostname=$HOSTNAME/g" utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties
}
