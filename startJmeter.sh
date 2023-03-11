if [ "$JMETER_HOME" == "" ] || [ ! -d $JMETER_HOME ] 
then
	echo "\$JMETER_HOME needs to be a directory!"
	exit 1
fi

java -jar $JMETER_HOME/bin/ApacheJMeter.jar -t examples/jmeter/teastore_browse_nogui.jmx -Jhostname localhost -Jport 8080 -JnumUser 10 -n 

docker ps | awk '{print $1}' | xargs docker stop $1
docker ps -a | awk '{print $1}' | xargs docker rm -f $1

USER=$(whoami)
sudo chown $USER:$USER kieker-results -R 
#echo "Parameters: "
#cd kieker-results && for file in $(echo */*); do echo -n "$(pwd)/$file "; done; echo


