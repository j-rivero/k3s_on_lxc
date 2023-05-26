#!/bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LIB_DIR="${SCRIPT_DIR}/lib"
PROVIDERS_LIB_DIR="${SCRIPT_DIR}/providers"
PROVIDER=${PROVIDER:-proxmox_lxc}
PROVIDER_DIR="${PROVIDERS_LIB_DIR}/${PROVIDER}"
PROVIDER_HOOK_FILE="${PROVIDER_DIR}/${PROVIDER}/hooks.bash"

# -------------------------------------------
# Useful variables
#
DEBUG=${DEBUG:-false}
# -------------------------------------------

source "${PROVIDER_HOOK_FILE}"
source "${LIB_DIR}/helm.bash"

_allow_root_login() {
  VMID=${1}

  hook_exec "${VMID}" "sed -i -e 's:^#PermitRootLogin.*:PermitRootLogin yes:' /etc/ssh/sshd_config"
  hook_exec "${VMID}" "systemctl restart sshd.service"
}

# -------------------------------------------
# START THE PROVISIONING
# -------------------------------------------
#
# 1. Create the VMs or system platforms

export VMID_SERVER
export VMID_AGENT

hook_provision_platform

# Server installation
echo "[ --- ]"
echo "[ SERVER ] Install the k3s server"
hook_exec_file ${VMID_SERVER} "install_k3s_server.bash"
echo "[ SERVER ] Install the helm package manager"
hook_exec_file ${VMID_SERVER} "install_helm.bash"
echo "[ TEST ] Check server installation"
hook_exec ${VMID_SERVER} "/usr/local/bin/kubectl get nodes > /dev/null 2>/dev/null"
echo "[ TEST ] Check helm installation"
hook_exec ${VMID_SERVER} "/usr/local/bin/helm version > /dev/null"
# Custom service configurations
if ${ALLOW_SSHD_ROOT}; then
  _allow_root_login "${VMID_SERVER}"
fi
# Server tests to run
if ${TEST_TRAEFIK}; then
  hook_exec_file ${VMID_SERVER} "test_whoami_traefik.bash"
fi

SERVER_TOKEN=$(hook_exec ${VMID_SERVER} "cat /var/lib/rancher/k3s/server/node-token" true)
SERVER_IP=$(hook_exec ${VMID_SERVER} "ifconfig eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'" true)

# Agent installation
echo "[ --- ]"
echo "[ AGENT ] Install the k3s agent"
hook_exec_file ${VMID_AGENT} "install_k3s_agent.bash" "${SERVER_IP}" "${SERVER_TOKEN}"
echo -n "[ TEST ] Check server connection"
hook_exec ${VMID_SERVER} "/usr/local/bin/kubectl get nodes | grep -q ${CLUSTER_INSTANCES[VMID_AGENT]}"
echo "[ --- ]"

# Install the helm packages in the server from the configuration file
_install_helm_packages "${VMID_SERVER}"
