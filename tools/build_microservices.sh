#!/usr/bin/env bash

echo "Building TeasTore microservices Docker Images"

image_output_dir='../examples/live-demo/images'
registry=''     # e.g. 'descartesresearch/'

print_usage() {
  printf "Usage: docker_build.sh [-p] [-r REGISTRY_NAME]\n"
}

docker build -t "teastore-db:latest" ../utilities/tools.descartes.teastore.database/
docker build -t "teastore-base:latest" ../utilities/tools.descartes.teastore.dockerbase/
perl -i -pe's|.*FROM descartesresearch/|FROM '"${registry}"'|g' ../services/tools.descartes.teastore.*/Dockerfile
docker build -t "teastore-registry:latest" ../services/tools.descartes.teastore.registry/
docker build -t "teastore-persistence:latest" ../services/tools.descartes.teastore.persistence/
docker build -t "teastore-image:latest" ../services/tools.descartes.teastore.image/
docker build -t "teastore-webui:latest" ../services/tools.descartes.teastore.webui/
docker build -t "teastore-auth:latest" ../services/tools.descartes.teastore.auth/
docker build -t "teastore-recommender:latest" ../services/tools.descartes.teastore.recommender/
perl -i -pe's|.*FROM '"${registry}"'|FROM descartesresearch/|g' ../services/tools.descartes.teastore.*/Dockerfile

# Delete existing .tar files before saving
for image in teastore-db teastore-base teastore-registry teastore-persistence teastore-image teastore-webui teastore-auth teastore-recommender; do
    rm -f "${image_output_dir}/${image}.tar"
done

# Try to save images
docker save -o "${image_output_dir}/teastore-db.tar" "teastore-db"
docker save -o "${image_output_dir}/teastore-base.tar" "teastore-base"
docker save -o "${image_output_dir}/teastore-registry.tar" "teastore-registry"
docker save -o "${image_output_dir}/teastore-persistence.tar" "teastore-persistence"
docker save -o "${image_output_dir}/teastore-image.tar" "teastore-image"
docker save -o "${image_output_dir}/teastore-webui.tar" "teastore-webui"
docker save -o "${image_output_dir}/teastore-auth.tar" "teastore-auth"
docker save -o "${image_output_dir}/teastore-recommender.tar" "teastore-recommender"
