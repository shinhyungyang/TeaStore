#!/usr/bin/env bash

javac -d /opt/kieker/java/target /opt/kieker/java/SocketLogServer.java
java -cp /opt/kieker/java/target SocketLogServer
