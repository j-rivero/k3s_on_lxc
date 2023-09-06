#!/bin/bash
set -e

if [[ $# -lt 2 ]]; then
  echo "Usage: install_helm_package <helm_package> <helm_repository_url> [version]"
  exit 1
fi

helm_package=${1}
namespace=${helm_package/-/}
helm_repository_url=${2}
helm_repository_name=${helm_package/-/}
helm_install_name="${namespace}"
version=${3}

# install script need local bin in the path
export PATH=$PATH:/usr/local/bin

kubectl create namespace "${namespace}"

helm repo add "${helm_repository_name}" "${helm_repository_url}"
helm repo update

if [[ ${version} ]]; then
  version_str=(--version "${version}")
fi

# Ugly but no other way https://github.com/helm/helm/issues/2655
status=$(helm status "${helm_package}" 2>&1 || true)
if [[ "${status}" != "Error: release: not found" ]]; then
  helm uninstall "${helm_package}"
fi

helm install --namespace "${namespace}" \
  "${helm_install_name}"\
  "${helm_repository_name}/${helm_package}"\
  "${version_str[@]}"
