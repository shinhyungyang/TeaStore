#!/bin/bash
push_flag='true'
registry='kieker/'     # e.g. 'descartesresearch/'
tag=':kieker-2.0.2'

print_usage() {
  printf "Usage: docker_build.sh [-p] [-r REGISTRY_NAME]\n"
}

while getopts 'pr:' flag; do
  case "${flag}" in
    p) push_flag='true' ;;
    r) registry="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

docker build -t "${registry}teastore-db${tag}" ../utilities/tools.descartes.teastore.database/
docker build -t "${registry}teastore-kieker-rabbitmq${tag}" ../utilities/tools.descartes.teastore.kieker.rabbitmq/
docker build -t "${registry}teastore-base${tag}" ../utilities/tools.descartes.teastore.dockerbase/
#perl -i -pe's|.*FROM descartesresearch/|FROM '"${registry}"'|g' ../services/tools.descartes.teastore.*/Dockerfile
docker build -t "${registry}teastore-registry${tag}" ../services/tools.descartes.teastore.registry/
docker build -t "${registry}teastore-persistence${tag}" ../services/tools.descartes.teastore.persistence/
docker build -t "${registry}teastore-image${tag}" ../services/tools.descartes.teastore.image/
docker build -t "${registry}teastore-webui${tag}" ../services/tools.descartes.teastore.webui/
docker build -t "${registry}teastore-auth${tag}" ../services/tools.descartes.teastore.auth/
docker build -t "${registry}teastore-recommender${tag}" ../services/tools.descartes.teastore.recommender/
#perl -i -pe's|.*FROM '"${registry}"'|FROM descartesresearch/|g' ../services/tools.descartes.teastore.*/Dockerfile

if [ "$push_flag" = 'true' ]; then
  docker push "${registry}teastore-db${tag}"
  docker push "${registry}teastore-kieker-rabbitmq${tag}"
  docker push "${registry}teastore-base${tag}"
  docker push "${registry}teastore-registry${tag}"
  docker push "${registry}teastore-persistence${tag}"
  docker push "${registry}teastore-image${tag}"
  docker push "${registry}teastore-webui${tag}"
  docker push "${registry}teastore-auth${tag}"
  docker push "${registry}teastore-recommender${tag}"
fi
