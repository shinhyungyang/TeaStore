# Prerequisites

You will need to have the following:

1.  minikube
2.  docker
3.  Make sure you got JDK 11 or above installed and $JAVA_HOME set correctly 
4.  Kieker
	1. Download the **Kieker** 1.15 Binaries
	 ```
     https://github.com/kieker-monitoring/kieker/releases/download/1.15/kieker-1.15-binaries.zip
	 ```
	2. Extract (unzip) the .zip you just downloaded


5. Copy Kieker's Trace Analysis .zip file into the TeaStore:
	1. Kieker Trace Analysis can be found in the previously downloaded binaries folder `kieker-1.15-binaries/kieker-1.15/tools/trace-analysis-1.15.zip`
	2. The location (TeaStore repository) where it should be pasted is `TeaStore/utilities/tools.descartes.teastore.kieker.demoserver/`

#  Architecture Visualization Deployment

1.  Get your IP (in the following lines referred as: `$IP`)

2. Get the IP for the minikube cluster (in the following lines referred as: `$MINIKUBE_IP`)
	1. hint command: `minikube ip`  

3. Start the Kieker Trace Analysis and the TeaStore (via minikube Kubernetes):
    1. The script will require sudo permissions to run the maven comand:
    2. `./startPods.sh $IP TRACEANALYSIS` 
    3. The TeaStore will be exposed at `http://$MINIKUBE_IP:30080/`
    4. The Graph Plotter Webapp will be exposed at`http://$MINIKUBE_IP:30082/`
4.  Make sure to restart minikube when applying changes.
