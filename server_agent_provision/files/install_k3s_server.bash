#!/bin/bash
set -e

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=" 
    --kubelet-arg=feature-gates=KubeletInUserNamespace=true\
    --kube-controller-manager-arg=feature-gates=KubeletInUserNamespace=true\
    --kube-apiserver-arg=feature-gates=KubeletInUserNamespace=true\
    --flannel-iface=eth0\
    --cluster-init\
    --disable servicelb\
    --disable traefik
    --write-kubeconfig-mode '644'" sh -s -

mkdir ~/.kube/
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 700 ~/.kube/config
