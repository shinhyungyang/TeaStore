#!/usr/bin/env bash

cd ..

echo "Deleting Previously stored graph..."
rm -rf kieker.log out/*

echo "Creating Graph via Kieker Trace Analysis..."
trace-analysis/bin/trace-analysis \
   --inputdirs kieker-logs \
   --outputdir out/ \
   --plot-Aggregated-Deployment-Call-Tree \
   --short-labels \
   --ignore-invalid-traces


echo "Converting Graph into PDF"
cd out/

dot aggregatedDeploymentCallTree.dot -T pdf -o output_graph.pdf
