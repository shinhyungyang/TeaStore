# Prerequisites

You will need to have the following:

1.  minikube
2.  docker
3.  Make sure you got JDK 11 or above installed and $JAVA_HOME set correctly 
4.  ExplorViz
	1. clone the **ExplorViz** Repository
		```
        git clone https://github.com/ExplorViz/deployment.git
		```
		
5.  Kieker
	1. clone the **Kieker** Repository   
	 ```
	 git clone https://github.com/kieker-monitoring/kieker.git
	 ```
	 
6. Make sure kieker is  built via `./gradlew assemble -x test -x check -x apidoc` (we use the current 2.0.0-SNAPSHOT)

7. Copy Kieker's OTel Transformer .zip file into the TeaStore:
	1. Kieker OTel Transformer can be found in `/kieker/tools/otel-transformer/build/distributions/otel-transformer-2.0.0-SNAPSHOT.zip`
	2. The location (TeaStore repository) where it should be pasted is `/TeaStore/utilities/tools.descartes.teastore.kieker.oteltransformer/`

#  Architecture Visualization Deployment

1. First, start ExplorViz (via docker-compose):
  1. Start: `export FRONTEND_PORT=8080 && docker compose pull && docker compose up -d` (The `FRONTEND_PORT` needs to be something that doesn't interfere with other ports used in the local machine, if port 8080 is free, the export part can be skipped)
  2. In case of restarts, make sure to shut it down via `docker compose down -v`
  
2.  Get your IP (in the following lines referred as: `$IP`)

3. Get the IP for the minikube cluster (in the following lines referred as: `$MINIKUBE_IP`)
	1. hint command: `minikube ip`  

5. Start the Kieker OTel Transformer and the TeaStore (via minikube Kubernetes):
    1. The script will require sudo permissions to run the maven comand:
    2. `./startPods.sh $IP OTELTRANSFORMER` 
    3. The TeaStore will be exposed at `http://$MINIKUBE_IP:30080/`
    4.  ExplorViz will be exposed at `http://$IP:8080/`
6.  Make sure to restart minikube when applying changes.
