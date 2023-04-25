#!/bin/bash

set -e

[[ -L ${0} ]] && SCRIPT_DIR=$(readlink ${0}) || SCRIPT_DIR=${0}
SCRIPT_DIR="${SCRIPT_DIR%/*}"

# -------------------------------------------
# Useful variables
#
DEBUG=${DEBUG:-false}
source "${SCRIPT_DIR}/config.bash"

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

_pct_create() {
  local VMID=${1} HOSTNAME=${2}

  LOG=$(pct create "${VMID}" "${VZ_IMAGE}" \
    --arch amd64 \
    --ostype "${OS_TYPE}" \
    --hostname "${HOSTNAME}"\
    --cores "${CORES}" \
    --memory "${RAM}" \
    --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp,type=veth \
    --storage local-lvm \
    --rootfs "local-lvm:${DISK_GB}" \
    --unprivileged 1 \
    --features nesting=1 \
    --password="${LXC_ROOT_PASS}" \
    --swap 0)

  if [[ $? != 0 ]]; then
    echo "[!!] pvc create command failed"
    echo "$LOG"
    exit 1
  fi

 PCT_VM_PATH="${LXC_DIRECTORY}/${VMID}.conf"
  if [[ ! -f ${PCT_VM_PATH} ]]; then
    echo "${PCT_VM_PATH} not found for then configuration of ${VMID}"
    exit 1
  fi
  # Extra lxc configuration not possible in pct create
  cat <<-EOF >> "${PCT_VM_PATH}"
lxc.cap.drop:
lxc.mount.auto: "proc:rw sys:rw"
lxc.cgroup2.devices.allow: c 10:200 rwm
EOF

  ${DEBUG} && pct config "${VMID}"
  return 0
}

_pct_start() {
  local VMID=${1}

  if ! pct start "${VMID}"; then
    echo "Problems starting ${VMID} server. Run debug start:"
    pct config "${VMID}"
    pct start "${VMID}" --debug
    exit 1
  fi
  return 0
}

_pct_exec() {
  local VMID=${1} CMD=${2} ENABLE_OUTPUT=${3:-false} ERR=false

  LOG=`pct exec "${VMID}" -- sh -c "${CMD}"` || ERR=true
  if $ERR; then
    echo "[ !! ] There was a problem running ${CMD} in ${VMID}"
    echo "${LOG}"
    exit 1
  fi

  [[ ${ENABLE_OUTPUT} ]] && echo "${LOG}"
  return 0
}

_pct_exec_file() {
  local VMID=${1} FILE_TO_EXEC=${2} ARG1=${3} ARG2=${4} ARG3=${5} ERR=false

  pct push "${VMID}" "files/${FILE_TO_EXEC}" "/tmp/${FILE_TO_EXEC}"
  pct exec "${VMID}" -- chmod +x "/tmp/${FILE_TO_EXEC}"
  LOG=`pct exec "${VMID}" -- "/tmp/${FILE_TO_EXEC}" "${ARG1}" "${ARG2}" "${ARG3}"` || ERR=true
  if $ERR; then
    echo "[ !! ] There was a problem running ${FILE_TO_EXEC} in ${VMID}"
    echo "${LOG}"
    exit 1
  fi
  pct exec "${VMID}" -- rm "/tmp/${FILE_TO_EXEC}"
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

echo "[ SERVER ] Install argo-cd"
_pct_exec_file ${VMID_SERVER} "install_helm_package.bash" \
  "argo-cd" \
  "https://argoproj.github.io/argo-helm" \
  "5.19.15"  # chart version 5.19.15 is argo v2.5.10
echo "[ TEST ] Check argocd service"
_pct_exec ${VMID_SERVER} "/usr/local/bin/kubectl get services | grep -q argocd-server"
echo "[ --- ]"
# kubectl port-forward service/argco-argocd-server -n default 8080:443 --address='0.0.0.0'
echo "[ SERVER ] Install harbor"
# chart version 1.3.18 is harbor 1.10.17 the required in specs. However, all versions under
# 1.6.0 fail to install on helm. 1.6.0 is harbor 2.2.0
_pct_exec_file ${VMID_SERVER} "install_helm_package.bash" \
   "harbor" \
   "https://helm.goharbor.io" \
   "1.6.0"
echo "[ TEST ] Check harbor service"
_pct_exec ${VMID_SERVER} "/usr/local/bin/kubectl get services | grep -q harbor-portal"
echo "[ --- ]"
# kubectl port-forward service/harbor-portal -n default 88:80 --address='0.0.0.0'
echo "[ SERVER ] Install prometheus"
_pct_exec_file ${VMID_SERVER} "install_helm_package.bash" \
  "prometheus" \
  "https://prometheus-community.github.io/helm-charts" \
  "20.2.1" # LTS not in the repo, use latest chart 20.2.1 is promethus v2.43.0
echo "[ TEST ] Check promethus service"
_pct_exec ${VMID_SERVER} "/usr/local/bin/kubectl get services | grep -q prometheus"
echo "[ SERVER ] Install grafana"
_pct_exec_file ${VMID_SERVER} "install_helm_package.bash" \
  "grafana" \
  "https://grafana.github.io/helm-charts/" \
  "6.54.0" # Chart version for 6.54.0 is app version 9.4.7
echo "[ TEST ] Check promethus service"
_pct_exec ${VMID_SERVER} "/usr/local/bin/kubectl get services | grep -q grafana"
echo "[ --- ]"
