#!/bin/bash

# Download & install Helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > install-helm.sh
chmod u+x install-helm.sh
./install-helm.sh
rm install-helm.sh

/usr/local/bin/helm init
