#
# Promox provider
#
# Use pct commmands from the system host to execute installation
# on Proxmox LXCs.
#

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
