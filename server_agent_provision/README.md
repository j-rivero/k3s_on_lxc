# Proxmox k3s Server Agent Provision

Simple bash provision script to be run on the Proxmox
host in order to create a Server and Agent k3s installation.

 * Create LXC instances in Proxmox
 * Install base packages in both instances
 * Install k3s server in one of the LXC
 * Install k3s agent in the other LXC
 * Connect the k3s agent to the server as k3s node

## Usage

Set up the root password in the secret file and run the script.

```bash
echo my_root_pass > secret
POOL_VMID_START_AT=100 ./create_k3s_server_agent_proxmox.bash
```

For using existing LXC instances and run only the provisioning
of HELM packages:

```bash
USE_EXISTING_VMID=100 ./create_k3s_server_agent_proxmox.bash
```

Variables to customize the creation:
  * `POOL_VMID_START_AT`: ID to start looking for an empty ID in Proxmox
  * `USE_EXISTING_VMID`: do not create LXC for agent/server and use the value
    passed for server and +1 for the agent,
  * `VZ_IMAGE`: Base PVE Image to use. Also change `OS_TYPE` if modified.
  * (see other variables in the first lines of the script)
