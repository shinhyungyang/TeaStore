#!/bin/bash

index=1
folder="debug_$index"

while [ -d "$folder" ]
do
	((index++))
	folder="debug_$index"
done

mkdir $folder
docker ps &> $folder/dockerps.txt
for container in $(cat $folder/dockerps.txt | awk '{print $1}')
do
	docker logs $container &> $folder/$container.txt
done
