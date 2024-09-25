#!/usr/bin/env bash

source executionControl/functions.sh

echo "Checking Kubernetes cluster status..."

if ! minikube status | grep -q "host: Running"; then
  echo "Starting Minikube"
  minikube start
else 
  echo "Minikube already running"
fi

cd examples/live-demo/images && ./load_minikube.sh
cd ../kubernetes

if [ "$1" ]
then
  case "$1" in
    "otel")
      kubectl create -f teastore-otel-transformer.yaml
      microservice_id=$(kubectl get pods | grep "otel" | awk '{print $1}')
      waitForPodStartup $microservice_id 'DEBUG RecordReceiverMain -- Running transformer'
      ;;
    "traceanalysis")
      kubectl create -f teastore-rabbitmq_v16.yaml
      microservice_id=$(kubectl get pods | grep "rabbitmq" | awk '{print $1}')
      waitForPodStartup $microservice_id 'Time to start RabbitMQ:'

      kubectl create -f teastore-demo-server.yaml
      microservice_id=$(kubectl get pods | grep "demo" | awk '{print $1}')
      waitForPodStartup $microservice_id 'INFO success: java-app entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)'
      waitForPodStartup $microservice_id 'INFO success: node-app entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)'
      ;;
  esac
fi


# the database will only be on the main server
kubectl create -f teastore-db.yaml
database_id=$(kubectl get pods | grep "teastore-db" | awk '{print $1}')
if [ ! -z "$database_id" ]
then	
  waitForPodStartup $database_id 'port: 3306'
fi

kubectl create -f teastore-registry.yaml
microservice_id=$(kubectl get pods | grep "registry" | awk '{print $1}')
waitForPodStartup $microservice_id 'org.apache.catalina.startup.Catalina.start Server startup in '

kubectl create -f teastore-persistence.yaml
microservice_id=$(kubectl get pods | grep "persistence" | awk '{print $1}')
waitForPodStartup $microservice_id 'org.apache.catalina.startup.Catalina.start Server startup in '

kubectl create -f teastore-auth.yaml
microservice_id=$(kubectl get pods | grep "auth" | awk '{print $1}')
waitForPodStartup $microservice_id 'org.apache.catalina.startup.Catalina.start Server startup in '

kubectl create -f teastore-recommender.yaml
microservice_id=$(kubectl get pods | grep "recommender" | awk '{print $1}')
waitForPodStartup $microservice_id 'org.apache.catalina.startup.Catalina.start Server startup in '

kubectl create -f teastore-image.yaml
microservice_id=$(kubectl get pods | grep "image" | awk '{print $1}')
waitForPodStartup $microservice_id 'org.apache.catalina.startup.Catalina.start Server startup in '

kubectl create -f teastore-webui.yaml
microservice_id=$(kubectl get pods | grep "webui" | awk '{print $1}')
waitForPodStartup $microservice_id 'org.apache.catalina.startup.Catalina.start Server startup in '

