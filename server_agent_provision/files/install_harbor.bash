#!/bin/bash
set -e

ARGOCD_VERSION=${1}

# Install script need local bin in the path
export PATH=$PATH:/usr/local/bin

helm repo add harbor https://helm.goharbor.io
helm repo update

if [[ ${ARGOCD_VERSION} ]]; then
  VERSION_STR="--version ${ARGOCD_VERSION}"
fi

helm install harbor harbor/harbor ${VERSION_STR}
