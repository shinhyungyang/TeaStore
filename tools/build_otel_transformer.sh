#!/usr/bin/env bash

echo "Building OTel Transformer Docker Image"
image_output_dir='../examples/live-demo/images'

docker build -t "teastore-otel-transformer:latest" ../utilities/tools.descartes.teastore.kieker.oteltransformer/

# Delete existing .tar files before saving
rm -f "${image_output_dir}/teastore-otel-transformer.tar"

# Try to save image
echo "Savig OTel transformer image locally"
docker save -o "${image_output_dir}/teastore-otel-transformer.tar" "teastore-otel-transformer"
