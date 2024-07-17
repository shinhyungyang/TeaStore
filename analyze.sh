#!/bin/bash

if [ "$KIEKER_HOME" == "" ] || [ ! -d $KIEKER_HOME ] 
then
	echo "\$KIEKER_HOME needs to be a directory!"
	exit 1
fi

set -e

start=$(pwd)

KIEKER_TOOLS_FOLDER="$KIEKER_HOME/tools/"

if [ ! -d $KIEKER_TOOLS_FOLDER/log-replayer/build/distributions/log-replayer-2.0.0-SNAPSHOT/ ]
then
	echo "Unzipping log-replayer-2.0.0-SNAPSHOT.zip"
	cd $KIEKER_TOOLS_FOLDER/log-replayer/build/distributions/ && unzip log-replayer-2.0.0-SNAPSHOT.zip &> /dev/null
	cd $start
fi


folders=$(cd kieker-results && for file in $(echo */*); do echo -n "$(pwd)/$file "; done; echo)
$KIEKER_TOOLS_FOLDER/log-replayer/build/distributions/log-replayer-2.0.0-SNAPSHOT/bin/log-replayer -n -i $folders &> summarize.txt
resultPath=$(cat summarize.txt | grep actualStoragePath | awk -F'=' '{print $2}' | tr -d "\'")

if [ ! -d $KIEKER_TOOLS_FOLDER/trace-analysis-new/build/distributions/trace-analysis-new-2.0.0-SNAPSHOT/ ]
then
	echo "Unzipping trace-analysis-new-2.0.0-SNAPSHOT.zip"
	cd $KIEKER_TOOLS_FOLDER/trace-analysis-new/build/distributions/ && unzip trace-analysis-new-2.0.0-SNAPSHOT.zip &> /dev/null
	cd $start
fi


mkdir graphs

$KIEKER_TOOLS_FOLDER/trace-analysis-new/build/distributions/trace-analysis-new-2.0.0-SNAPSHOT/bin/trace-analysis-new \
	-i $resultPath \
	-o $(pwd)/graphs \
	--plot-Deployment-Component-Dependency-Graph responseTimes-ms \
	--plot-Deployment-Operation-Dependency-Graph responseTimes-ms \
	--plot-Aggregated-Deployment-Call-Tree \
	--plot-Aggregated-Assembly-Call-Tree &> plottingOutput.txt
	
cd graphs && for file in *.dot; do dot -Tpng $file -o $file.png; done
