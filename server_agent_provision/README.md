# k3 Server - Agent Provision

Minimal provisioner written in bash to setup a k3s server <-> agent
installation in enviroments where other real provisioning tools can not
be used.

## Proxmox k3s Server Agent Provision

Simple bash provision script to be run on the Proxmox
host in order to create a Server and Agent k3s installation.

 * Create LXC instances in Proxmox
 * Install base packages in both instances
 * Install k3s server in one of the LXC
 * Install/Test ingress controller (nginx-ingress by default) in the k3s server
 * Install k3s agent in the other LXC
 * Connect the k3s agent to the server as k3s node

## Usage with proxmox_lxc

Set up the root password in the secret file and run the script.

```bash
cd server_agent_provision
echo 'LXC_ROOT_PASS=my_root_pass' > ./providers/proxmox_lxc/secret.bash
PROVIDER=proxmox_lxc POOL_VMID_START_AT=100 ./create_k3s_server_agent_proxmox.bash
```

For using existing LXC instances and run only the provisioning
of HELM packages:

```bash
PROVIDER=proxmox_lxc USE_EXISTING_VMID=100 ./create_k3s_server_agent_proxmox.bash
```

For development cases, the provisoning can install only the server if needed:
```bash
PROVIDER=proxmox_lxc ONLY_SERVER=true ./create_k3s_server_agent_proxmox.bash
```

### Helm packages in the Server

For installing helm packages inside the server, the plain text configuration
file [`server_helm_packages`](server_helm_packages) can be used. The format
is described in the file.


### Configuration

Variables to customize the creation are stored in the [config file](providers/proxmox_lxc/config.bash)
with descriptions. They control the ID assignation in Proxmox and the
specs of the LXC machines to create.
