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
echo 'LXC_ROOT_PASS=my_root_pass' > secret.bash
POOL_VMID_START_AT=100 ./create_k3s_server_agent_proxmox.bash
```

For using existing LXC instances and run only the provisioning
of HELM packages:

```bash
USE_EXISTING_VMID=100 ./create_k3s_server_agent_proxmox.bash
```

## Configuration

Variables to customize the creation are stored in the [config file](config.bash)
with descriptions. They control the ID assignation in Proxmox and the
specs of the LXC machines to create.

### Helm packages in the server

For installing helm packages inside the server, the plain text configuration
file [`server_helm_packages`](server_helm_packages) can be used. The format
is described in the file.
