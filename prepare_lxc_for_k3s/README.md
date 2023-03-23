# Prepare LXC to install k3s

Actions in the host and in the LXC container need to be performed

## System context

Host: Debian Bullseye 11
Kernel: 5.15.30-2-pve
Proxmox 7.2.3
k3s: 

## One-time: initial setup in the host

Disable swap:
```
sysctl vm.swappiness=0
swapoff -a
```
Enable IP forwarding:
```
sudo sysctl net.ipv4.ip_forward=1
sudo sysctl net.ipv6.conf.all.forwarding=1
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.confsudo sysctl net.ipv4.ip_forward=1
```

## One-time: create the LXC container template

Create unpriviledged containers with swap set to 0

Using the ID given to the container, modify in the filesystem of the host
`/etc/pve/lxc/$ID.conf`
```
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.mount.auto: "proc:rw sys:rw"
lxc.cgroup2.devices.allow: c 10:200 rwm
```

Run the `prepare_lxc.bash` script in this repo to perform the remaining actions
and install basic packages to continue the process of installing and debugging
k3s.

## Create server lx3 installation




## Links

 * https://davegallant.ca/blog/2021/11/14/running-k3s-in-lxc-on-proxmox/
 * https://kevingoos.medium.com/kubernetes-inside-proxmox-lxc-cce5c9927942
 * https://github.com/k3s-io/k3s/issues/4249
