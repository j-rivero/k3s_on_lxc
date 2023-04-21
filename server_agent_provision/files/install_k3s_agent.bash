#!/bin/bash

if [ $# -lt 2 ]; then
  echo "Usage ${0} <server_ip> <token>"
  exit 1
fi

SERVER_IP=${1}
TOKEN=${2}

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=--kubelet-arg=feature-gates=KubeletInUserNamespace=true \
  K3S_URL=https://${SERVER_IP}:6443 \
  K3S_TOKEN=${TOKEN} sh -s -

# Give time to the connection before more actions are done
sleep 1
