function analyzeCallCounts {
	FOLDER=$1
	SERVLET=$2
	# for call counts, we need grep $SERVLET -A 1
	traceIds=$(cat $FOLDER/teastore-*/*/*.dat | grep -v "RegistryClient\$1.<init>" | grep $SERVLET | awk -F';' '{print $5}')

	echo -n "#Service Call Counts: "
	echo $traceIds | awk '{print NF}'

	#for traceId in $traceIds
	#do
	#	echo -n "$traceId "
	#	cat $1/teastore-*/*/*.dat | grep $traceId | wc -l
	#done | awk '{if (NR % 2 == 0) {print prev + $2} prev=$2;}'

	for traceId in $traceIds
	do
		echo -n "$traceId "
		grep $traceId $1/teastore-*/*/*.dat | awk -F';' '{print $8}' | uniq | wc -l
	done
}

for servlet in IndexServlet LoginActionServlet CartServlet CartActionServlet CategoryServlet ProductServlet
do
	echo "Analyzing: $servlet"
	analyzeCallCounts $1 $servlet &> $servlet.txt
done
