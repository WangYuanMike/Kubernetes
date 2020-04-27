#!/bin/bash

#############################################################################
# Description:
#   - Install k8s master from greenfield ubuntu server
# Remarks:
#   - Put kubeadm-config.yaml in the same directory before running
#   - Run it with root user
#   - Run it with command "source k8s_master_init.sh" so that all k8s env
#     and configuration will take effect directly in current bash shell
#   - Only tested with AWS EC2 node (2 vCPU, 8GB memory)
#############################################################################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   return
fi

# Update OS
apt-get update && apt-get upgrade -y

# Install docker
apt-get install -y docker.io

# Setup docker daemon (change its cgroupdriver to systemd)
cat >> /etc/docker/daemon.json <<EOF
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
echo "deb  http://apt.kubernetes.io/  kubernetes-xenial  main" >> /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-get update

# Install the k8s software
apt-get install -y kubeadm=1.17.1-00 kubelet=1.17.1-00 kubectl=1.17.1-00
