# -------------------------------------------
# Configuration variables
#

# File hosting Proxmox crendetianls
export SECRETS_FILE="secret.bash"

# Server VMID USE_EXISTING_VMID value is passed. The Agent will be assumed
# as USE_EXISTING_VMID value + 1.
export USE_EXISTING_VMID=${USE_EXISTING_VMID:-0}
# VMID (LXC internal ID in proxmox) to start looking for free IDS in Proxmox to create
# server and agent. Not used if USE_EXISTING_VMID was supplied.
export POOL_VMID_STARTS_AT=${POOL_VMID_STARTS_AT:-100}

# LXC creation variables. Configuration is being shared between
# agent and server.
export LXC_DIRECTORY=/etc/pve/lxc
export VZ_IMAGE=/var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
export OS_TYPE=ubuntu
export CORES=8
export RAM=20000
export DISK_GB=40
export BASE_APT_PACKAGES="curl vim net-tools"
# -------------------------------------------
