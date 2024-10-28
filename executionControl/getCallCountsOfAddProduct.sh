traceIds=$(cat $1/teastore-*/*/*.dat | grep -v "RegistryClient\$1.<init>" | grep CartActionServlet -A 1 | awk -F';' '{print $5}')

for traceId in $traceIds
do
	echo -n "$traceId "
	cat $1/teastore-*/*/*.dat | grep $traceId | wc -l
done | awk '{if (NR % 2 == 0) {print prev + $2} prev=$2;}'
