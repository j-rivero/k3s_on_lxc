#!/bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LIB_DIR="${SCRIPT_DIR}/lib"

# -------------------------------------------
# Useful variables
#
DEBUG=${DEBUG:-false}
source "${SCRIPT_DIR}/config.bash"
HELM_PACKAGES_CONFIG_PATH="${SCRIPT_DIR}/server_helm_packages"

# -------------------------------------------

${DEBUG} && pveam available

if [[ ! -f ${VZ_IMAGE} ]]; then
  echo "${VZ_IMAGE} not found in the filesystem"
  exit 1
fi

source ${SECRETS_FILE}

if [[ -z ${LXC_ROOT_PASS} ]]; then
  echo "LXC_ROOT_PASS is empty. Set it in ${SECRETS_FILE} file"
  exit 1
fi

source "${LIB_DIR}/provider_proxmox.bash"
source "${LIB_DIR}/helm.bash"

_allow_root_login() {
  VMID=${1}

  _pct_exec "${VMID}" "sed -i -e 's:^#PermitRootLogin.*:PermitRootLogin yes:' /etc/ssh/sshd_config"
  _pct_exec "${VMID}" "systemctl restart sshd.service"
}

# -------------------------------------------
# START THE PROVISIONING
# -------------------------------------------
if [[ ${USE_EXISTING_VMID} -gt 0 ]]; then
  VMID_SERVER=${USE_EXISTING_VMID}
  VMID_AGENT=$(( USE_EXISTING_VMID + 1 ))
else
  # Defining machines in the cluster
  VMID_SERVER=${POOL_VMID_STARTS_AT}
  while pct config ${VMID_SERVER} > /dev/null 2> /dev/null; do
    VMID_SERVER=$(( VMID_SERVER + 1 ))
  done
  VMID_AGENT=$(( VMID_SERVER +1 ))
  while pct config ${VMID_AGENT} > /dev/null 2> /dev/null; do
    VMID_AGENT=$(( VMID_AGENT + 1 ))
  done
fi
CLUSTER_INSTANCES=()
CLUSTER_INSTANCES[VMID_SERVER]="cluster-k3s-server-${VMID_SERVER}"
CLUSTER_INSTANCES[VMID_AGENT]="cluster-k3s-agent-${VMID_SERVER}"

if [[ ${USE_EXISTING_VMID} -eq 0 ]]; then
  # Base installation for all the instances
  for VMID in "${!CLUSTER_INSTANCES[@]}"; do
    HOSTNAME=${CLUSTER_INSTANCES[VMID]}
    echo "[ --- ] Creating instance ${HOSTNAME} with ID ${VMID}"
    echo "[ RUN ] Building the PVE instance"
    _pct_create "${VMID}" "${HOSTNAME}"
    echo "[ RUN ] Starting the PVE instance"
    _pct_start "${VMID}"
    echo "[ RUN ] Base packages installation"
    _pct_exec "${VMID}" "sed -i -e 's:# en_US.UTF-8 UTF-8:en_US.UTF-8 UTF-8:' /etc/locale.gen"
    _pct_exec "${VMID}" "locale-gen > /dev/null 2> /dev/null"
    _pct_exec "${VMID}" "apt-get -qq update"
    _pct_exec "${VMID}" "apt-get install -qq -o=Dpkg::User-Pty=0 -y ${BASE_APT_PACKAGES} > /dev/null"
    echo "[ RUN ] Prepare for the k3s installation"
    _pct_exec_file "${VMID}" "prepare_lxc_for_k3s.bash"
    echo "[ --- ]"
    echo
  done
  # Server installation
  echo "[ --- ]"
  echo "[ SERVER ] Install the k3s server"
  _pct_exec_file ${VMID_SERVER} "install_k3s_server.bash"
  echo "[ SERVER ] Install the helm package manager"
  _pct_exec_file ${VMID_SERVER} "install_helm.bash"
  echo "[ TEST ] Check server installation"
  _pct_exec ${VMID_SERVER} "/usr/local/bin/kubectl get nodes > /dev/null 2>/dev/null"
  echo "[ TEST ] Check helm installation"
  _pct_exec ${VMID_SERVER} "/usr/local/bin/helm version > /dev/null"
  # Custom service configurations
  if ${ALLOW_SSHD_ROOT}; then
    _allow_root_login "${VMID_SERVER}"
  fi
  # Server tests to run
  if ${TEST_TRAEFIK}; then
    _pct_exec_file ${VMID_SERVER} "test_whoami_traefik.bash"
  fi

  SERVER_TOKEN=$(_pct_exec ${VMID_SERVER} "cat /var/lib/rancher/k3s/server/node-token" true)
  SERVER_IP=$(_pct_exec ${VMID_SERVER} "ifconfig eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'" true)

  # Agent installation
  echo "[ --- ]"
  echo "[ AGENT ] Install the k3s agent"
  _pct_exec_file ${VMID_AGENT} "install_k3s_agent.bash" "${SERVER_IP}" "${SERVER_TOKEN}"
  echo -n "[ TEST ] Check server connection"
  _pct_exec ${VMID_SERVER} "/usr/local/bin/kubectl get nodes | grep -q ${CLUSTER_INSTANCES[VMID_AGENT]}"
  echo "[ --- ]"
else
  echo "[ --- ] Reusing server ${VMID_SERVER} and agent ${VMID_AGENT}"
fi

# Install the helm packages in the server from the configuration file
_install_helm_packages "${VMID_SERVER}"
