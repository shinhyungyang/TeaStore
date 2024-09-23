#!/usr/bin/env bash

echo "Loading local TeaStore images to Kubernetes cluster..."

tarFiles="$(ls *.tar)"
for file in $tarFiles
do
  minikube image load "$file"
  echo "image loaded $file"
done

echo "Finished loading images to Kubernetes cluster"
