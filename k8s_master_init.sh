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
# Update OS
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
echo "deb  http://apt.kubernetes.io/  kubernetes-xenial  main" >> /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-get update

# Install and hold the k8s software
apt-get install -y kubeadm=1.17.1-00 kubelet=1.17.1-00 kubectl=1.17.1-00
apt-mark hold kubelet kubeadm kubectl

# Download pod network(Calico) for CNI(Container Network Interface)
wget https://tinyurl.com/yb4xturm -O rbac-kdd.yaml
wget https://docs.projectcalico.org/manifests/calico.yaml

# Maintain the ip address of server's primary interface in /etc/hosts
cp /etc/hosts /etc/hosts.bak  # backup
echo "$(hostname -i) k8smaster" >> /etc/hosts

# Intialize k8s
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.out

# Maintain KUBECONFIG env for root user
cp /etc/bash.bashrc /etc/bash.bashrc.bak  # backup
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bashrc

# Configure k8s auto completion
# Check more details by running "kubectl completion -h"
# https://kubernetes.io/docs/tasks/tools/install-kubectl/#enabling-shell-autocompletion
apt-get install bash-completion -y
echo "source /usr/share/bash-completion/bash_completion" >> ~/.bashrc
echo "source <(kubectl completion bash)" >> ~/.bashrc

# Source the bash config file for k8s env and config to take effect in current shell
source ~/.bashrc

# Apply the network plugin so that pod can communciate with each other
kubectl apply -f rbac-kdd.yaml
kubectl apply -f calico.yaml
