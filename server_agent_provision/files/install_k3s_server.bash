#!/bin/bash
set -e

# Be very carefull touching any space or scapes in this command since
# it is easy that it ends up not generating a valid systemd file.
# For debbuging: see /etc/systemd/system/k3s.service
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=" 
    --kubelet-arg=feature-gates=KubeletInUserNamespace=true\
    --kube-controller-manager-arg=feature-gates=KubeletInUserNamespace=true\
    --kube-apiserver-arg=feature-gates=KubeletInUserNamespace=true\
    --flannel-iface=eth0\
    --cluster-init\
    --disable traefik
    --write-kubeconfig-mode '644'" sh -s -

mkdir ~/.kube/
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 700 ~/.kube/config

# Note the use of the provider/cloud controller here to use a nodeport as External IP
# see: https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#over-a-nodeport-service
# The URL can be changed to provider/baremetal but in that case a pool of IPs needs to be
# provided according to the documentation
/usr/local/bin/kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
