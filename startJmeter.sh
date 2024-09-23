#!/bin/bash

if [ $# -lt 1 ]
then
	echo "Please provide IP as parameter! (Parameters: ./startJmeter.sh \$WEBUI_IP"
	exit 1
fi


if [ "$JMETER_HOME" == "" ] || [ ! -d $JMETER_HOME ] 
then
	echo "\$JMETER_HOME needs to be a directory!"
	exit 1
fi

WEBUI_IP=$1

java -jar $JMETER_HOME/bin/ApacheJMeter.jar \
	-t examples/jmeter/teastore_browse_nogui.jmx -n \
	-Jhostname $WEBUI_IP -Jport 8080 -JnumUser 10 -JrampUp 1

docker ps | grep teastore | awk '{print $1}' | xargs docker stop $1
docker ps -a | grep teastore | awk '{print $1}' | xargs docker rm -f $1

USER=$(whoami)
sudo chown $USER:$USER kieker-results -R 
#echo "Parameters: "
#cd kieker-results && for file in $(echo */*); do echo -n "$(pwd)/$file "; done; echo


