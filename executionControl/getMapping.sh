#!/bin/bash

methods=$(cat ../kieker-results/teastore-*/kieker*/*dat | grep -v "RegistryClient\$1.<init>" | grep -v "2.0.0-SNAPSHOT" | awk -F';' '{print $3}' | awk '{print $NF}' | sort | uniq)

for method in $methods
do
	echo -n "$method "
	cat ../kieker-results/teastore-*/kieker*/*dat | grep -v "RegistryClient\$1.<init>" | awk -F';' '{print $3}' | grep $method | wc -l
done
