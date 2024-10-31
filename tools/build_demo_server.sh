#!/usr/bin/env bash

echo "Building Demo Server Docker Image"
image_output_dir='../examples/live-demo/images'

BASE_DIR="${PWD}"
TMP_DIR="$(mktemp -d)"
cd "${TMP_DIR}"
wget https://github.com/kieker-monitoring/kieker/releases/download/1.15/kieker-1.15-binaries.zip
unzip kieker-1.15-binaries.zip
mv kieker-1.15/tools/trace-analysis-1.15.zip ${BASE_DIR}/../utilities/tools.descartes.teastore.kieker.demoserver
cd "${BASE_DIR}"
rm -rf "${TMP_DIR}"

docker build -t "teastore-demo-server:latest" ../utilities/tools.descartes.teastore.kieker.demoserver/
docker build -t "teastore-kieker-rabbitmq:latest" ../utilities/tools.descartes.teastore.kieker.rabbitmq/

# Delete existing .tar files before saving
rm -f "${image_output_dir}/teastore-demo-server.tar"
rm -f "${image_output_dir}/teastore-kieker-rabbitmq.tar"

# Try to save image
docker save -o "${image_output_dir}/teastore-demo-server.tar" "teastore-demo-server"
docker save -o "${image_output_dir}/teastore-kieker-rabbitmq.tar" "teastore-kieker-rabbitmq"
