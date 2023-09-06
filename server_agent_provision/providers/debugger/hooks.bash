#
# Promox provider
#
# Use pct commmands from the system host to execute installation
# on Proxmox LXCs.
#

#
# Implement the exec and exec_file hook
# For Proxmox system base use _pvt_ functqions
#

hook_exec() {
  local SYSTEM_FILE=${1} CMD=${2} ENABLE_OUTPUT=${3:-false} ERR=false

  echo "sh -c \"${CMD}\"" >> "${SYSTEM_FILE}"

  [[ ${ENABLE_OUTPUT} ]] && echo "${LOG}"
  return 0
}

hook_cp() {
  local SYSTEM_FILE=${0} LOCAL_FILE=${1} REMOTE_FILE=${2}

  echo "cp ${LOCAL_FILE} ${REMOTE_FILE}" >> ${SYSTEM_FILE}
}

hook_exec_file() {
  local SYSTEM_FILE=${1} FILE_TO_EXEC=${2} ARG1=${3} ARG2=${4} ARG3=${5} ERR=false

  echo "# Running file: ${FILES_DIR}/${FILE_TO_EXEC}" >> ${SYSTEM_FILE}
  echo "${FILES_DIR}/${FILE_TO_EXEC} \"${ARG1}\" \"${ARG2}\" \"${ARG3}\"" >> ${SYSTEM_FILE}
  return 0
}

#
# Implement the hook_provision_platform:
# Use plain text files for debugging
#
hook_provision_platform() {
  VMID_SERVER="/tmp/.k3_debugger_vmid_server"
  VMID_AGENT="/tmp/.k3_debugger_vmid_agent"

  echo "[ --- ] Created debug system server in file ${VMID_SERVER}"
  echo "[ --- ] Created debug system agent in file ${VMID_AGENT}"
}
