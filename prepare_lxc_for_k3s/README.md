# Prepare LXC to install k3s

Actions in the host and in the LXC container need to be performed

## System context

* Host: Debian Bullseye 11
* Kernel: 5.15.30-2-pve
* Proxmox 7.2.3
* k3s: v1.25.7+k3s1

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

## Create server k3s installation

Using the template created above

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=" 
    --kubelet-arg=feature-gates=KubeletInUserNamespace=true\
    --kube-controller-manager-arg=feature-gates=KubeletInUserNamespace=true\
    --kube-apiserver-arg=feature-gates=KubeletInUserNamespace=true\
    --flannel-iface=eth0\
    --cluster-init\
    --disable servicelb\
    --disable traefik
    --write-kubeconfig-mode '644'" sh -s - 
```
Check the result
```bash
root@cluster-k3s-server:~# kubectl get nodes
NAME                 STATUS   ROLES                       AGE     VERSION
cluster-k3s-server   Ready    control-plane,etcd,master   6m16s   v1.25.7+k3s1
```

## Create agent 

### Actions in the server

Some information is needed from the k3s server: IP and token
```bash
root@cluster-k3s-server:~# hostname -I | awk '{print $1}'
(ip)
root@cluster-k3s-server:~# cat /var/lib/rancher/k3s/server/node-token
(token)
```

### Actions in the agent

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=--kubelet-arg=feature-gates=KubeletInUserNamespace=true K3S_URL=https://(ip-from-previous-step):6443 K3S_TOKEN=(token-from-previous-step) sh -
```

## Troubleshooting

### /proc/sys/net/netfilter/nf_conntrack_max: permission denied

Fixed in [k8s upstream](https://github.com/k3s-io/k3s/pull/3505).

Seems not to be critical. **Solution: ** syslog should display the problem.
```
grep nf_conntrack_max /var/log/syslog | tail -n 2
cluster-k3s-agent1 k3s[xx]: time="xxx" level=info msg="Set sysctl 'net/netfilter/nf_conntrack_max' to 786432"
cluter-k3s-agent1 k3s[xx]: time="xxx" level=error msg="Failed to set sysctl: open /proc/sys/net/netfilter/nf_conntrack_max: permission denied"
```

Use the 786432 number displayed in syslog.

Back to the **host system**:
```
sysctl -w net/netfilter/nf_conntrack_max=786432
```

### /proc/sys/vm/overcommit_memory: permission denied

```
container_manager_linux.go:435] "Updating kernel flag failed (Hint: enable KubeletInUserNamespace feature flag to ignore the error)" err="open /proc/sys/vm/overcommit_memory: permission denied" flag="vm/overcommit_memory"
```

Critical. **Solution**: as suggested, use the `INSTALL_K3S_EXEC=--kubelet-arg=feature-gates=KubeletInUserNamespace=true` flag when installating the server or the agent.

### failed to apply oom score -999 to PID 460: write /proc/460/oom_score_adj: permission denied

```
460 container_manager_linux.go:505] "Failed to ensure process in container with oom score" err="failed to apply oom score -999 to PID 460: write /proc/460/oom_score_adj: permission denied"
```

Happen in [unpriviledges containers](https://github.com/lxc/lxd/issues/2994#issuecomment-283759615) and seems not to be critical to connect the agent and the server. A [possible workaround](https://github.com/lxc/lxd/issues/2994) was submitted bug ignored.

## Links

 * https://davegallant.ca/blog/2021/11/14/running-k3s-in-lxc-on-proxmox/
 * https://kevingoos.medium.com/kubernetes-inside-proxmox-lxc-cce5c9927942
 * https://github.com/k3s-io/k3s/issues/4249
