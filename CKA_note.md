# LFS258 CKA

## 3 Installation and Configuration
### 3.0 System requirement of each node in cloud
- 2 vCPU, 7.5G memory
- Ubuntu 16.04 (xenial)
### 3.1 Install K8S master
#### Run script k8s_master_init.sh with root user
- **Pre-requisite: manually put kubeadm-config.yaml in the same directory**
- Install container runtime
- Change container's cgroup driver to systemd
- Install kubectl, kubeadm, kubelet
- Download pod network (Calico) to use for CNI (Container Network Interface)
- Maintain an alias(k8smaster) for the server's primary ip address
- Initialize k8s
- export KUBECONFIG=/etc/kubernetes/admin.conf
- Add kubectl auto completion
- Apply network plugin configuration to cluster (Calico and its RBAC)
#### Then run script k8s_master_non_root_init.sh for any non-root k8s user
- Copy k8s admin config file and change permission
- Add kubectl auto completion
#### Remarks 
- **Docker runtime**
  - Need to change the cgroup driver of container runtime to systemd before installing k8s
  - Docker uses cgroupfs as default cgroup driver, this will make kubelet also to use cgroupfs as its cgroup driver. This will cause two resource managers in charge in the k8s cluster, cgroupfs for docker and k8s, and systemd for other processes in the OS
  - Useful links:
    - [install container runtime before executing kubeadm](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
    - [control and configure docker with systemd](https://docs.docker.com/v17.09/engine/admin/systemd/)
    - [using systemd to control the docker daemon](https://success.docker.com/article/using-systemd-to-control-the-docker-daemon)
- **Bash**
  - [bash manual](https://www.gnu.org/software/bash/manual/html_node/index.html#SEC_Contents)
  - `ps -ef --forest` is useful for checking relationship between bash shell processes
- **Calico**
  - [Kubernetes network with Calico](https://www.tigera.io/blog/kubernetes-networking-with-calico/)
### 3.2 Grow Cluster
#### Run script k8s_worker_init.sh with root user
- Install container runtime
- Change container's cgroup driver to systemd
- Install kubectl, kubeadm, kubelet
- Initialize k8s
#### Do these steps manually with root user on both nodes
- **[Master]**Generate the worker node join command by running `kubeadm token create --print-join-command` which would create a new k8s token and corresponding hash
- **[Worker]**Maintain an alias(k8smaster) of the master node's primary ip address in work node's /etc/hosts
- **[Worker]**Join worker node by running the join command generated in the first step
#### Check result
- **[Master]**Run `kubectl get nodes` to check the newly joined node
- **[Worker]**`.kube/config` does not exist yet, therefore `kubectl get nodes` does not work on worker node
#### Remarks
- **Troubleshooting**
  - Use `telnet k8smaster 6443` on worker node to test connection to the apiserver on k8s master node
  - If connection is fine, then the problem is probably due to an invalid token. Just rerun the command `kubeadm token create --print-join-command` on master node, and try the newly generated join command on worker node
### 3.3 Finish Cluster Setup
- **[Master]**Run `kubectl taint nodes --all node-role.kubernetes.io/master-` to delete this default taints. For training purpose, we deliberately delete this taints to allow non-infrastructure pods being deployed on the master node. Also run `kubectl taint nodes --all node.kubernetes.io/not-ready-` if this taint is presented in the output of `kubectl describe node <node_name> | grep -i taint`.
- Check `coredns` pods are running
- Check `tunl0` interface is created
- On both nodes use `ip route` to check route table to get an overview about ip, interface, node, pod, subnet and so on
### 3.4 Deploy A Simple Application
- Two ways to create deployment: 
- use nginx image directly `kubectl create deployment nginx --image=nginx`
- use deployment yaml file `kubectl create -f first.yaml`
- Three ways to check deployment in yaml format:
- `kubectl get deployment nginx -o yaml`
- `kubectl create deployment two --image=nginx --dry-run -o yaml`
- `kubect get deployments nginx --export -o yaml` (no unique info, e.g. createTime, Status)
- Add container port info in deployment yaml file
- Patch deployment with container port `kubectl replace -f first.yaml`
- Create service of nginx deployment `kubectl expose deployment/nginx`  
- Scale deployment with more replicas `kubectl scale deployment nginx --replicas=3`
- Get end point (pod ip) of nginx `kubectl get ep nginx`
- Start monitoring tcp traffic on tunl0 interface of both nodes `sudo tcp -i tunl0`
- Curl to the nginx service cluster ip and corresponding pod ip and watch tcpdump of tunl0
- Delete some nginx pod and watch tcp traffic in tun10 `kubectl delete pod nginx-.....`
- **Remarks**
  - I saw traffic through tunl0 when curl to nginx service cluster ip or endpoint, but did not see any traffic through tunl0 when deleting nginx pod
### 3.5 Access from Outside the Cluster
- Delete existing nginx service `kubectl delete svc nginx`
- Create a new nginx service with type LoadBalancer `kubectl expose deployment nginx --type=LoadBalancer`
- Get the port of the LoadBalancer service `kubectl get svc nginx`
- Use public IP of any node and serivce port to access nginx web server for verification

