#!/usr/bin/env bash

if [ $# -lt 1 ]
then
	echo "Please provide IP as parameter!"
	exit 1
fi

if [ $# -gt 3 ]
then
	container_id=$3
	agent_ip=$4
	if [[ $agent_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
	then
		echo "IP $agent_ip will be used for the current host"
	else
		echo "IP $agent_ip not valid; exiting"
		exit 1
	fi
else
	container_id="1"
fi

MY_IP=$1
BASE_DIR=`pwd`
MY_FOLDER="$BASE_DIR/kieker-results/"

set -e

source executionControl/functions.sh

resetInstrumentationFiles


if [ "$2" ]
then
	case "$2" in
		"NO_INSTRUMENTATION") removeAllInstrumentation ;;
		"DEACTIVATED") 
			git checkout -- utilities/tools.descartes.teastore.dockerbase/start.sh
			sed -i 's/\(export JAVA_OPTS=".*\)"/\1 -Dkieker.monitoring.enabled=false"/' utilities/tools.descartes.teastore.dockerbase/start.sh
			;;
		"NOLOGGING")
			git checkout -- utilities/tools.descartes.teastore.dockerbase/start.sh
			sed -i 's/\(export JAVA_OPTS=".*\)"/\1 -Dkieker.monitoring.writer=kieker.monitoring.writer.dump.DumpWriter -Dkieker.monitoring.core.controller.WriterController.RecordQueueFQN=kieker.monitoring.writer.dump.DumpQueue"/' utilities/tools.descartes.teastore.dockerbase/start.sh
			;;
		"TCP")
			# nohup is necessary on Rocky Linux, otherwise, the process gets finished after script end; with Ubuntu, it works without
			nohup java -jar utilities/receiver.jar 10001 &> "kieker-receiver.log" &
			sed -i "s/kieker.monitoring.writer=kieker.monitoring.writer.filesystem.FileWriter/#kieker.monitoring.writer=kieker.monitoring.writer.filesystem.FileWriter/g" utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties
			sed -i "s/#kieker.monitoring.writer=kieker.monitoring.writer.tcp.SingleSocketTcpWriter/kieker.monitoring.writer=kieker.monitoring.writer.tcp.SingleSocketTcpWriter/g" utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties
		  sed -i "s/kieker.monitoring.writer.tcp.SingleSocketTcpWriter.hostname=localhost/kieker.monitoring.writer.tcp.SingleSocketTcpWriter.hostname=teastore-otel-transformer-service/g" utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties
		  # sed -i "s/kieker.monitoring.writer.tcp.SingleSocketTcpWriter.bufferSize=655350/kieker.monitoring.writer.tcp.SingleSocketTcpWriter.bufferSize=655350/g" utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties
			sed -i "s/kieker.monitoring.writer.tcp.SingleSocketTcpWriter.flush=false/kieker.monitoring.writer.tcp.SingleSocketTcpWriter.flush=true/g" utilities/tools.descartes.teastore.dockerbase/kieker.monitoring.properties

			sed -i "s|kieker.tools.oteltransformer.stages.OpenTelemetryExporterStage.ExportURL=http://IP_PLACEHOLDER:55678/|kieker.tools.oteltransformer.stages.OpenTelemetryExporterStage.ExportURL=http://$MY_IP:55678/|g" utilities/tools.descartes.teastore.kieker.oteltransformer/server/resources/kieker.monitoring.properties
			;;
		"KIEKER_ASPECTJ_TEXT")
			# Do nothing, since this is the default configuration
			;;
		"KIEKER_ASPECTJ_BINARY")
			useBinaryWriterKieker
			;;
		"KIEKER_BYTEBUDDY_TEXT")
			instrumentForKiekerBytebuddy
			;;
		"KIEKER_BYTEBUDDY_BINARY")
			instrumentForKiekerBytebuddy
			useBinaryWriterKieker
			;;
		"OPENTELEMETRY_DEACTIVATED")
			removeAllInstrumentation
			instrumentForOpenTelemetry $MY_IP "DEACTIVATED"
			;;
		"OPENTELEMETRY_SPANS")
			removeAllInstrumentation
			instrumentForOpenTelemetry $MY_IP
			;;
		*) echo "Configuration $2 not found; Exiting"; exit 1;;
  esac
fi

echo "Building current version..."

# sudo ./mvnw clean package -DskipTests &> build.txt
sudo mvn clean install -DskipTests -e

maven_exit_status=$?
if [ $maven_exit_status -eq 1 ]; then
    echo "Maven build did not succeed - cancelling"
    exit 1
else
    echo "Maven build was succesful"
fi

(
  cd tools
  ./build_microservices.sh
  ./build_otel_transformer.sh
)

if [ -d $MY_FOLDER ] && [ ! -z "$( ls -A $MY_FOLDER )" ]
then
	docker run --rm -v $MY_FOLDER:/kieker-results alpine sh -c "rm -rf /kieker-results/*"
#	sudo rm -rf $MY_FOLDER/*
fi

mkdir -p $MY_FOLDER

echo "Creating docker containers..."

if [ $container_id == "1" ]
then
  ./deployPods.sh
fi

minikube_ip=$(minikube ip)
waitForFullstartup $minikube_ip 30080

# Errase the IP form the config at the end
sed -i "s|kieker.tools.oteltransformer.stages.OpenTelemetryExporterStage.ExportURL=http://$MY_IP:55678/|kieker.tools.oteltransformer.stages.OpenTelemetryExporterStage.ExportURL=http://IP_PLACEHOLDER:55678/|g" utilities/tools.descartes.teastore.kieker.oteltransformer/server/resources/kieker.monitoring.properties

echo -e "Deployment Finished."
