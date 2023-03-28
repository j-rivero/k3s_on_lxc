#!/bin/bash

set -e

[[ -L ${0} ]] && SCRIPT_DIR=$(readlink ${0}) || SCRIPT_DIR=${0}
SCRIPT_DIR="${SCRIPT_DIR%/*}"

DEBUG=${DEBUG:-false}

# Configuration variables
SECRETS_FILE="${SCRIPT_DIR}/secret"
POOL_VMID_STARTS_AT=3000 # _VMID to start looking for free IDS in Proxmox
# LXC variables
LXC_DIRECTORY=/etc/pve/lxc
VZ_IMAGE=/var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
OS_TYPE=ubuntu
CORES=8
RAM=20000
DISK_GB=40
BASE_APT_PACKAGES="curl vim net-tools"

${DEBUG} && pveam available
${DEBUG} && pvesm available

if [[ ! -f ${VZ_IMAGE} ]]; then
  echo "${VZ_IMAGE} not found in the filesystem"
  exit 1
if

source ${SECRETS_FILE}

if [[ ! -z ${LXC_ROOT_PASS} ]]; then
  echo "LXC_ROOT_PASS is empty. Set it in ${SECRETS_FILE} file"
  exit 1
fi

VMID_SERVER=${POOL_VMID_STARTS_AT}
while pct config ${VMID_SERVER} 2> /dev/null
  VMID_SERVER=$(( $VMID_SERVER + 1 ))
do

VMID_AGENT=$(( ${VMID_SERVER} +1 ))
while pct config ${VMID__AGENT} 2> /dev/null
  VMID__AGENT=$(( $VMID__AGENT + 1 ))
do

SERVER_NAME="cluster-k3s-server-${VMID_SERVER}"
AGENT_NAME="cluser-k3s-agent-${VMID_SERVER}"

_pct_create() {
  local VMID=${0} HOSTNAME=${1}

  pct create ${VMID} ${VZ_IMAGE} \
    --arch amd64 \
    --ostype ${OS_TYPE} \
    --hostname ${HOSTNAME}\
    --cores ${CORES} \
    --memory ${RAM} \
    --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp,type=veth \
    --storage local-lvm \
    --rootfs local-lvm:${DISK_GB} \
    --unprivileged 1 \
    --features nesting=1 \
    --password=${LXC_ROOT_PASS} \
    --swap 0

  if [[ $? != 0 ]]; then
    echo "[!!] pvc create command failed. Check above for the error"
    exit 1
  fi

  PCT_VM_PATH="${LXC_DIRECTORY}/${VMID}.conf"
  if [[ ! -f ${PCT_VM_PATH} ]]; then
    echo "${PCT_VM_PATH} not found for then configuration of ${VMID}"
    exit 1
  fi
  # Extra lxc configuration not possible in pct create
  cat <<-EOF >> ${PCT_VM_PATH}
  lxc.apparmor.profile: unconfined
  lxc.cap.drop: 
  lxc.mount.auto: "proc:rw sys:rw"
  lxc.cgroup2.devices.allow: c 10:200 rwm
  EOF
  
  ${DEBUG} && pct config ${VMID}
}

_pct_start() {
  local VMID=${0} 

  if [[ ! pct start ${VMID} ]]; then
    echo "Problems starting ${VMID} server. Run debug start:"
    pct config ${VMID}
    pct start ${VMID} --debug 
    exit 1
  fi
}

_pct_exec() {
  local VMID=${0} CMD=${1} ENABLE_OUTPUT=${2:-false}

  LOG=$(pct exec ${VMID} -- ${CMD})
  if [[ %? != 0 ]]; then
    echo "[ !! ] There was a problem running ${CMD} in ${VMID}"
    echo "${LOG}"
    exit 1
  fi

  [[ {ENABLE_OUTPUT} ]] && echo ${LOG}
}

echo "[ S1 ] Building PVE server ${SERVER_NAME}"
_pct_create ${VMID_SERVER} ${SERVER_NAME}
echo "[ S2 ] Starting PVE server"
_pct_start ${VMID_SERVER}
echo "[ S3 ] Base packages installation"
_pct_exec ${VMID_SERVER} "apt-get update && apt-get install -y ${BASE_APT_PACKAGES}"
echo "[ S4 ] Server k3s installation"
_pct_exec ${VMID_SERVER} "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\" 
    --kubelet-arg=feature-gates=KubeletInUserNamespace=true\
    --kube-controller-manager-arg=feature-gates=KubeletInUserNamespace=true\
    --kube-apiserver-arg=feature-gates=KubeletInUserNamespace=true\
    --flannel-iface=eth0\
    --cluster-init\
    --disable servicelb\
    --disable traefik
    --write-kubeconfig-mode '644'\" sh -s -"


SERVER_IP=$(_pct_exec ${VMID_SERVER} "hostname -I | awk '{print \$1}'" true)
SERVER_TOKEN=$(_pct_exec ${VMID_SERVER}) "cat /var/lib/rancher/k3s/server/node-token" true)
