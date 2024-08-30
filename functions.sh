function resetInstrumentationFiles {
	git checkout -- utilities/tools.descartes.teastore.dockerbase/Dockerfile
	git checkout -- utilities/tools.descartes.teastore.dockerbase/kieker-2.0.0-SNAPSHOT-aspectj.jar
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
       
       sed -i '/^COPY kieker-2.0.0-SNAPSHOT-aspectj\.jar/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
       sed -i '/^COPY kieker\.monitoring\.properties/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
       sed -i '/^COPY aop\.xml/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
       rm utilities/tools.descartes.teastore.dockerbase/kieker-*
       cp no-instrumentation-sources/* utilities/tools.descartes.teastore.registryclient/src/main/java/tools/descartes/teastore/registryclient/rest/
}

function instrumentForOpenTelemetry {
	MY_IP=$1
	DEACTIVATED=$2

	if [ ! -f utilities/tools.descartes.teastore.dockerbase/opentelemetry-javaagent.jar ]
	then
		curl -L -O https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar
		mv opentelemetry-javaagent.jar utilities/tools.descartes.teastore.dockerbase/opentelemetry-javaagent.jar
	fi
	
	git checkout -- utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY kieker-2.0.0-SNAPSHOT-aspectj\.jar/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY kieker\.monitoring\.properties/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY aop\.xml/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	
	sed -i '/^EXPOSE 8080/i COPY opentelemetry-javaagent.jar \/opentelemetry\/agent\/agent.jar' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	git checkout -- utilities/tools.descartes.teastore.dockerbase/start.sh
	
	if [[ "$2" != "DEACTIVATED" ]]
	then
		sed -i 's|-javaagent:/kieker/agent/agent.jar|-javaagent:/opentelemetry/agent/agent.jar -Dotel.metrics.exporter=none -Dotel.exporter.otlp.endpoint=http://'$MY_IP':4318|g' utilities/tools.descartes.teastore.dockerbase/start.sh
	
		docker run -d \
			--name teastore-otel-collector \
			-p 4318:4318 \
			otel/opentelemetry-collector-contrib:0.108.0
	else
		sed -i 's|-javaagent:/kieker/agent/agent.jar|-javaagent:/opentelemetry/agent/agent.jar -Dotel.metrics.exporter=none -Dotel.metrics.exporter=none|g' utilities/tools.descartes.teastore.dockerbase/start.sh
	fi	
}

function instrumentForKiekerBytebuddy {
	if [ ! -f utilities/tools.descartes.teastore.dockerbase/kieker-2.0.0-SNAPSHOT-bytebuddy.jar ]
	then
		curl https://oss.sonatype.org/content/repositories/snapshots/net/kieker-monitoring/kieker/2.0.0-SNAPSHOT/kieker-2.0.0-20240830.133533-823-bytebuddy.jar
		mv kieker-2.0.0-20240830.133533-823-bytebuddy.jar utilities/tools.descartes.teastore.dockerbase/kieker-2.0.0-SNAPSHOT-bytebuddy.jar
	fi

	sed -i 's/kieker-2.0.0-SNAPSHOT-aspectj/kieker-2.0.0-SNAPSHOT-bytebuddy/g' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY aop\.xml/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	
	echo 'echo "export KIEKER_SIGNATURES_INCLUDE=\"tools.descartes.teastore.[A-z]*\"" >> /usr/local/tomcat/bin/setenv.sh' >> utilities/tools.descartes.teastore.dockerbase/start.sh
	echo 'echo "export KIEKER_SIGNATURES_EXCLUDE=\"tools.descartes.teastore.kieker.[A-z]*;tools.descartes.teastore.entities.[A-z]*;tools.descartes.teastore.rest.[A-z]*;tools.descartes.teastore.registryclient.loadbalancers.[A-z]*;tools.descartes.teastore.registryclient.RegistryClient;tools.descartes.teastore.auth.startup.AuthStartup;tools.descartes.teastore.registryclient.StartupCallbackTask;tools.descartes.teastore.registryclient.RegistryClientHeartbeatDaemon;tools.descartes.teastore.registryclient.Service;tools.descartes.teastore.registryclient.StartupCallback;tools.descartes.teastore.registryclient.rest.RestUtil;tools.descartes.teastore.persistence.daemons.[A-z]*;tools.descartes.teastore.persistence.domain.converters.[A-z]*;tools.descartes.teastore.persistence.repository.[A-z]*;tools.descartes.teastore.persistence.servlet.[A-z]*;tools.descartes.teastore.persistence.rest.DatabaseGenerationEndpoint;tools.descartes.teastore.recommender.servlet.IndexServlet;tools.descartes.teastore.recommender.servlet.RetrainDaemon;tools.descartes.teastore.recommender.servlet.RecommenderStartup;tools.descartes.teastore.recommender.rest.TrainEndPoint;tools.descartes.teastore.recommender.algorithm.impl.UseFallBackException;tools.descartes.teastore.recommender.algorithm.OrderItemSet;tools.descartes.teastore.recommender.algorithm.AbstractRecommender;tools.descartes.teastore.webui.startup.[A-z]*;tools.descartes.teastore.webui.servlet.elhelper.[A-z]*;tools.descartes.teastore.webui.servlet.AbstractUIServlet;tools.descartes.teastore.image.setup.CachingMode;tools.descartes.teastore.image.setup.CachingRule;tools.descartes.teastore.image.setup.CreatorFactory;tools.descartes.teastore.image.setup.CreatorRunner;tools.descartes.teastore.image.setup.ImageCreator;tools.descartes.teastore.image.setup.ImageIDFactory;tools.descartes.teastore.image.setup.ImageProviderStartup;tools.descartes.teastore.image.setup.StorageMode;tools.descartes.teastore.image.setup.StorageRule;tools.descartes.teastore.image.storage.rules.[A-z]*;tools.descartes.teastore.image.cache.rules.[A-z]*;tools.descartes.teastore.image.cache.entry.[A-z]*;tools.descartes.teastore.image.ImageDB;tools.descartes.teastore.image.ImageDBKey;tools.descartes.teastore.image.ImageScaler;tools.descartes.teastore.image.StoreImage;tools.descartes.teastore.image.cache.AbstractQueueCache;tools.descartes.teastore.image.cache.AbstractTreeCache;tools.descartes.teastore.image.cache.FirstInFirstOut;tools.descartes.teastore.image.cache.IDataCache;tools.descartes.teastore.image.cache.LastInFirstOut;tools.descartes.teastore.image.cache.LeastFrequentlyUsed;tools.descartes.teastore.image.cache.LeastRecentlyUsed;tools.descartes.teastore.image.cache.MostRecentlyUsed;tools.descartes.teastore.image.cache.RandomReplacement;tools.descartes.teastore.registryclient.rest.HttpWrapper;tools.descartes.teastore.registryclient.rest.TrackingFilter;tools.descartes.teastore.registryclient.rest.ResponseWrapper;tools.descartes.teastore.registryclient.rest.CharResponseWrapper;tools.descartes.teastore.registryclient.rest.CharResponseWrapper.*;tools.descartes.teastore.image.cache.AbstractCache;tools.descartes.teastore.image.cache.AbstractCache.*;tools.descartes.teastore.registryclient.rest.NonBalancedCRUDOperations;tools.descartes.teastore.registryclient.util.RESTClient;tools.descartes.teastore.registryclient.util.RESTClient$1;tools.descartes.teastore.registryclient.util.AbstractCRUDEndpoint;tools.descartes.teastore.registryclient.tracing.Tracing\"" >> /usr/local/tomcat/bin/setenv.sh' >> utilities/tools.descartes.teastore.dockerbase/start.sh

}
