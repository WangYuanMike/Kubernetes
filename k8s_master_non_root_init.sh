#!/bin/bash

#############################################################################
# Description:
#   - Init config for non-root k8s user
# Remarks:
#   - Run it after running k8s_master_init.sh
#   - Run it with non-root user
#   - Run it with command "source k8s_master_non_root_init.sh" so that all k8s env
#     and configuration will take effect directly in current bash shell
#   - Only tested with AWS EC2 node (2 vCPU, 8GB memory)
#############################################################################
# Copy k8s admin config file and change permission
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Configure k8s auto completion
# Check more details by running "kubectl completion -h"
# https://kubernetes.io/docs/tasks/tools/install-kubectl/#enabling-shell-autocompletion
echo "source /usr/share/bash-completion/bash_completion" >> ~/.bashrc
echo "source <(kubectl completion bash)" >> ~/.bashrc

# Source the bash config file for k8s env and config to take effect in current shell
source ~/.bashrc