#!/bin/bash

function getSum {
  awk '{sum += $1; square += $1^2} END {print sqrt(square / NR - (sum/NR)^2)" "sum/NR" "NR}'
}

function runOneExperiment {
	PARAMETER=$1
	RESULTFILE=$2
	NUMUSER=$3
	
	ssh $TEASTORE_RUNNER_IP 'docker ps -a | grep "teastore\|recommender" | awk "{print \$1}" | xargs docker rm -f \$1'

	ssh -t $TEASTORE_RUNNER_IP "cd TeaStore; ./start.sh $HOST_SELF_IP $PARAMETER"

	echo
	echo
	echo "Building is finished; Starting load test"

	if [ -f $RESULTFILE ]
	then
	       rm $RESULTFILE
	fi
	
	sleep 60s

	echo "Replacing user count by $NUMUSER"
	
	sed -i '/>num_user/{n;s/.*/\            <stringProp name="Argument.value"\>'$NUMUSER'\<\/stringProp\>/}' examples/jmeter/teastore_browse_nogui.jmx

	java -jar $JMETER_HOME/bin/ApacheJMeter.jar \
	       -t examples/jmeter/teastore_browse_nogui.jmx -Jhostname localhost -Jport 8080 -n \
	       -l $RESULTFILE

	echo
	echo
	echo "Load test is finished; Removing containers"

	ssh $TEASTORE_RUNNER_IP 'docker ps -a | grep "teastore\|recommender" | awk "{print \$1}" | xargs docker rm -f \$1'
	
	if [[ "$PARAMETER" == "TCP" ]]
	then
		echo "Stopping receiver"
		# Don't fail on the next one, it usually works and still gives return code 255
		(ssh -t $TEASTORE_RUNNER_IP 'kill -9 $(pgrep -f receiver.jar)') || true
	fi
	
	sleep 5s
}

set -e

if [ $# -lt 1 ]
then
	echo "Please provide IP as parameter!"
	exit 1
fi

if [ "$JMETER_HOME" == "" ] || [ ! -d $JMETER_HOME ] 
then
	echo "\$JMETER_HOME needs to be a directory!"
	exit 1
fi

TEASTORE_RUNNER_IP=$1
if [ $# -gt 1 ]
then
	HOST_SELF_IP=$2
else
	HOST_SELF_IP=$TEASTORE_RUNNER_IP
fi

# Just test connection
ssh -q $1 "exit"

ssh $TEASTORE_RUNNER_IP "if [ ! -d TeaStore ]; then git clone https://github.com/DaGeRe/TeaStore.git; fi"
ssh $TEASTORE_RUNNER_IP "cd TeaStore; git checkout kieker-debug; git pull"

durations=""
loops=10
for (( iteration=1; iteration<=$loops; iteration++ ))
do
	start=$(date +%s%N)
	for NUMUSER in 1 2 4 8 16
	do
		runOneExperiment "NO_INSTRUMENTATION" no_instrumentation_$NUMUSER"_"$iteration.csv $NUMUSER
		runOneExperiment "DEACTIVATED" deactivated_$NUMUSER"_"$iteration.csv $NUMUSER
		runOneExperiment "NOLOGGING" nologging_$NUMUSER"_"$iteration.csv $NUMUSER
		runOneExperiment " " aspectj_instrumentation_$NUMUSER"_"$iteration.csv $NUMUSER
		runOneExperiment "TCP" tcp_$NUMUSER"_"$iteration.csv $NUMUSER
		runOneExperiment "OPENTELEMETRY_DEACTIVATED" otel_deactivated_$NUMUSER"_"$iteration.csv $NUMUSER
		runOneExperiment "OPENTELEMETRY" otel_$NUMUSER"_"$iteration.csv $NUMUSER
	done
	end=$(date +%s%N)
	duration=$(echo "($end-$start)/1000000" | bc)
	durations="$durations $duration"
	average=$(echo $durations | getSum | awk '{print $2/1000}')
	remaining=$(echo "scale=2; $average*($loops-$iteration)/60" | bc -l)
	echo " Remaining: $remaining minutes"
done
