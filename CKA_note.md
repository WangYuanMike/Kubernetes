# LFS258 CKA

## Installation and Configuration
### Installation procedure
- **Run script k8s_master_init.sh with root user in the master node**
    - Install container runtime
    - Change container's cgroup driver to systemd
    - Install kubectl, kubeadm, kubelet
    - Download pod network (Calico)
    - Initialize k8s
    - export KUBECONFIG=/etc/kubernetes/admin.conf

### Container runtime
- Need to change the cgroup driver of container runtime to systemd before installing k8s
- Docker uses cgroupfs as default cgroup driver, this will make kubelet also to use cgroupfs as its cgroup driver. This will cause two resource managers in charge in the k8s cluster, cgroupfs for docker and k8s, and systemd for other processes in the OS
- This has been taken into account in script k8s_master_init.sh
- Useful links:
    - [install container runtime before executing kubeadm](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
    - [control and configure docker with systemd](https://docs.docker.com/v17.09/engine/admin/systemd/)
    - [using systemd to control the docker daemon](https://success.docker.com/article/using-systemd-to-control-the-docker-daemon)

### Kubenetes config file
- For root user, it needs to specify /etc/kubernetes/admin.conf
```
kubectl --kubeconfig /etc/kubernetes/admin.conf get all --all-namespaces
```
- Or set environment variable KUBECONFIG beforehand
```
export KUBECONFIG=/etc/kubernetes/admin.conf
```
- This has been taken into account in script k8s_master_init.sh

### What happens right after executing "kubeadm init"?
```
root@ip-172-31-42-202:~# kubectl get all --all-namespaces
NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE
kube-system   pod/coredns-5644d7b6d9-w8scq                   0/1     Pending   0          53m
kube-system   pod/coredns-5644d7b6d9-z7x94                   0/1     Pending   0          53m
kube-system   pod/etcd-ip-172-31-42-202                      1/1     Running   0          52m
kube-system   pod/kube-apiserver-ip-172-31-42-202            1/1     Running   0          52m
kube-system   pod/kube-controller-manager-ip-172-31-42-202   1/1     Running   0          52m
kube-system   pod/kube-proxy-gjz5q                           1/1     Running   0          53m
kube-system   pod/kube-scheduler-ip-172-31-42-202            1/1     Running   0          52m

NAMESPACE     NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
default       service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP                  53m
kube-system   service/kube-dns     ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   53m

NAMESPACE     NAME                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 AGE
kube-system   daemonset.apps/kube-proxy   1         1         1       1            1           beta.kubernetes.io/os=linux   53m

NAMESPACE     NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
kube-system   deployment.apps/coredns   0/2     2            0           53m

NAMESPACE     NAME                                 DESIRED   CURRENT   READY   AGE
kube-system   replicaset.apps/coredns-5644d7b6d9   2         2         0       53m
```