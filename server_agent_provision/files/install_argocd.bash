#!/bin/bash
set -e

ARGOCD_VERSION=${1}

# Install script need local bin in the path
export PATH=$PATH:/usr/local/bin

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

if [[ ${ARGOCD_VERSION} ]]; then
  VERSION_STR="--version ${ARGOCD_VERSION}"
fi

helm install argco argo/argo-cd ${VERSION_STR}
