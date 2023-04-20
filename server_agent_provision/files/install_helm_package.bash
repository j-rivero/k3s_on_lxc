#!/bin/bash
set -e

if [[ $# -lt 2 ]]; then
  echo "Usage: install_helm_package <helm_package> <helm_repository_url> [version]"
  exit 1
fi

helm_package=${1}
helm_repository_url=${2}
version=${3}

# install script need local bin in the path
export PATH=$PATH:/usr/local/bin

helm repo add "${helm_package}" "${helm_repository_url}"
helm repo update

if [[ ${version} ]]; then
  version_str=(--version "${version}")
fi

helm install "${helm_package}/${helm_package}" "${version_str[@]}"
