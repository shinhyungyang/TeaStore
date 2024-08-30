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
	sed -i 's/kieker-2.0.0-SNAPSHOT-aspectj/kieker-2.0.0-SNAPSHOT-bytebuddy/g' utilities/tools.descartes.teastore.dockerbase/Dockerfile
	sed -i '/^COPY aop\.xml/d' utilities/tools.descartes.teastore.dockerbase/Dockerfile
}
