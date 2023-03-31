#!/bin/bash
set -e

# Install script need local bin in the path
export PATH=$PATH:/usr/local/bin

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argco argo/argo-cd
