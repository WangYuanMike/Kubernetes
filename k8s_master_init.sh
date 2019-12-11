#!/bin/bash

apt-get update && apt-get upgrade -y

# Install docker
apt-get install -y docker.io

# Setup docker daemon (change its cgroupdriver to systemd)
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker

# Add new repo for k8s
cat > /etc/apt/sources.list.d/ <<EOF
deb  http://apt.kubernetes.io/  kubernetes-xenial  main
EOF

apt-get update

# Install and hold the k8s software
apt-get install -y kubeadm=1.16.1-00 kubelet=1.16.1-00 kubectl=1.16.1-00
apt-mark hold kubelet kubeadm kubectl