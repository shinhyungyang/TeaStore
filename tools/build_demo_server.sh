#!/usr/bin/env bash

echo "Building Demo Server Docker Image"
image_output_dir='../examples/live-demo/images'

docker build -t "teastore-demo-server:latest" ../utilities/tools.descartes.teastore.kieker.demoserver/

# Delete existing .tar files before saving
rm -f "${image_output_dir}/teastore-demo-server.tar"

# Try to save image
docker save -o "${image_output_dir}/teastore-demo-server.tar" "teastore-demo-server"
