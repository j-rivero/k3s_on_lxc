#!/bin/bash

apt-get update
apt-get install -y \
  curl \
  net-tools \
  vim

cat <<-EOF > /etc/rc.local
#!/bin/sh -e
# Kubeadm 1.15 needs /dev/kmsg to be there, but it’s not in lxc, but we can just use /dev/console instead
# see: https://github.com/kubernetes-sigs/kind/issues/662
if [ ! -e /dev/kmsg ]; then
  ln -s /dev/console /dev/kmsg
fi
# https://medium.com/@kvaps/run-kubernetes-in-lxc-container-f04aa94b6c9c
mount --make-rshared /
EOF
/etc/rc.local
