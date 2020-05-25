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
- **[Master]** Generate the worker node join command by running `kubeadm token create --print-join-command` which would create a new k8s token and corresponding hash
- **[Worker]** Maintain an alias(k8smaster) of the master node's primary ip address in work node's /etc/hosts
- **[Worker]** Join worker node by running the join command generated in the first step
#### Check result
- **[Master]** Run `kubectl get nodes` to check the newly joined node
- **[Worker]** `.kube/config` does not exist yet, therefore `kubectl get nodes` does not work on worker node
#### Remarks
- **Troubleshooting**
  - Use `telnet k8smaster 6443` on worker node to test connection to the apiserver on k8s master node
  - If connection is fine, then the problem is probably due to an invalid token. Just rerun the command `kubeadm token create --print-join-command` on master node, and try the newly generated join command on worker node
### 3.3 Finish Cluster Setup
- **[Master]** Run `kubectl taint nodes --all node-role.kubernetes.io/master-` to delete this default taints. For training purpose, we deliberately delete this taints to allow non-infrastructure pods being deployed on the master node. Also run `kubectl taint nodes --all node.kubernetes.io/not-ready-` if this taint is presented in the output of `kubectl describe node <node_name> | grep -i taint`.
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
#### Remarks
- I saw traffic through tunl0 when curl to nginx service cluster ip or endpoint, but did not see any traffic through tunl0 when deleting nginx pod
### 3.5 Access from Outside the Cluster
- Delete existing nginx service `kubectl delete svc nginx`
- Create a new nginx service with type LoadBalancer `kubectl expose deployment nginx --type=LoadBalancer`
- Get the port of the LoadBalancer service `kubectl get svc nginx`
- Use public IP of any node and serivce port to access nginx web server for verification
## 4 Kubernetes Architecture
### 4.1 Working with CPU and Memory Constraints
- Create a deployment called **hog** to generate load `kubectl create deployment hog --image vish/stress`
- Export **hog.yaml**, the yaml file of hog deployment, and add resource limit and request to it 
- Replace hog deployment and check the resource allocation and utilization
  - check memory allocation `kubectl logs <hog-pod-name>`
  - Use `top` command to monitor CPU and memory utilization of process triggered by command **stress**
- Add arguments to stress program in hog.yaml to consume CPU and memory
- Use the above memthods to recheck the resource allocation and consumption status
### 4.2 Resource Limits for a Namespace
- Create a namespace `kubectl create namespace low-usage-limit`
- Create **low-resource-range.yaml** file to define LimitRange of the namespace
- Create a LimitRange of the namespace `kubectl -n=low-usage-limit create -f low-resource-range.yaml`
- Create a deployment in low-usage-limit namespace `kubectl -n low-usage-limit create deployment limited-hog --image vish/stress`
- Create **hog2.yaml** based on **hog.yaml** and make following changes:
  - Add namespace low-usage-limit
  - delete selfLink
- Use hog2.yaml to create a pod with its own resource limit in namespace low-usage-limit
- There should be three kinds of hog pods in the k8s cluster now:
  - default: hog
  - low-usage-limit: limited-hog
  - low-usage-limit: hog
- **default: hog** and **low-usage-limit: hog** should both have 100% CPU and about 950MB memory consumption, because pod's resource limit would override the one of namespace
### 4.3 Basic Node Maintenance
- Create a deployment and scale to create plenty of pods
  - `kubectl create deployment maint --image=nginx`
  - `kubectl scale deployment maint --replicas=20`
- Use `sudo docker ps | wc -l` to count the number or running docker processes on each node
- Now drain the worker node:
  - `kubectl drain <worker node name>`
  - If it encounters errors from DaemoneSet, run `kubectl drain <worker node name> --ignore-damonsets --delete-local-data`
- The above commands will add a taint on the worker node to prevent pods being scheduled onto it. Check it by `kubectl describe node | grep -i taint`
- When the node can be used again after maintenance, then uncordon it `kubectl uncordon <worker node name>`
## 5 APIs and Access
### 5.1 Configuring TLS Access
- Prepare ca certificate, client certificate, and client private key:
  - Retrieve data from `~./kube/config`
  - Create pem file, e.g. `echo $client | base64 -d - > ./client.pem`
- Execute curl command with these three pem files to access kube-apiserver
  - `curl --cert ./client.pem --key ./client-key.pem --cacert ./ca.pem https://k8smaster:6443/api/v1/pods`
- Create pod through curl
  - create a json file `curlpod.json` for to-be-created pod first
  - `curl --cert ./client.pem --key ./client-key.pem --cacert ./ca.pem https://k8smaster:6443/api/v1/pods -XPOST -H'Content-Type: application/json' -d @curlpod.json`
#### Remarks
- TLS keys (i.e. cacert, client cert, and client private key) are mandatory for accessing kube-apiserver. When using kubectl, it handles the TLS key stuff automatically for the user. When using curl or golang client, the TLS keys need to be taken care by the user through the ways mentioned above
- kube-apiserver only accepts json format input, e.g. pod description. kubectl converts yaml file into json, while curl and golang does not do the convert. Therefore the input for them could only be json. So as the output
- kube-apiserver requires a **Mutual TLS**, i.e. not only the server needs to prove its identity to the client, but the client needs to prove its identity to the server as well. That's why client cert and corresponding private key are needed in this case. Mutual TLS is normally used in the distributed system instead of the common browser/server scenario
- [This Video](https://youtu.be/yzz3bcnWf7M?t=4726) explains the mechanism of the Mutual TLS. It also covers a lot of other aspects of TLS in the entire video
- One can also use `curl -k` option to avoid using TLS keys, which would perform **insecure** SSL connections and transfer 
- There are three ways to access api server via curl as shown below. Check the other two ways in the chapter below.
  - cacert + client cert + client private key
  - cacert + token
  - proxy
### 5.2 Explore API Calls
- Use strace to dump the operations of a k8s api call to a file `strace -o kubectl get endpoints > strace.out`
- Search for system call `openat` in the dump file
- One shoudl find many `openat` calls for directory `~/.kube/cache/discovery/k8smaster_6443`
- Pick any of the directorys under the one mentioned above and look at the json in it, .e.g.
  - `python3 -m json.tool <above_dir>/v1/serverresources.json | grep kind`
  - `python3 -m json.tool <above_dir>/apps/v1/serverresources.json | grep kind`
#### Remarks
- `~/.kube/cache/discovery/k8smaster_6443` provide meta-data of the k8s API objects, e.g. kind, name, shortnames, verbs/actions. It is a good place to check the skeleton of kube-apiserver
## 6 API Objects
### 6.1 RESTful API Access
- Get secret which contains token in default namespace `kubectl get secrets`
- Get token out of the secret `export token=$(kubectl describe secret <secret-of-default-user> | grep ^token | cut -d ' ' -f 7)`
- Use token to access k8s api server `curl https://k8smaster:6443/apis -H "Authorization: Bearer $token" --cacert ./ca.pem`
#### Remarks
- Bearer token could be an option to replace the client certificate and client private key which are mentioned in last chapter
- `systemserviceaccount` is used in accessing the api server. Therefore, objects like namespace are not allowed to access due to missing RBAC authorization of this user
- Token and server certificate are automatically made available to a pod under `/var/run/secrets/kubernetes.io/serviceaccount/` so that pod could make use of the token and certificate to access api server
### 6.2 Using the Proxy
- Setup k8s proxy on master node `kubectl proxy --api-prefix=/ &` which listens on `http://127.0.0.1:8001` by default
- Access api server through the proxy `curl http://127.0.0.1:8001/api/`
#### Remarks
- proxy handles authentication (cert, key, or token) for curl
- namespace can also be accessed because proxy makes the request on your behalf
- proxy can be setup in a pod as well
- setup a proxy on localhost is troubleshooting method which could narrow the issue, e.g. if a user could not access namespace with the token way, while the proxy way works, then it means the issue is narrowed to the missing authentication or authorization of the user
### 6.3 Working with Jobs
#### Create a Job
- Create `job.yaml`, using busybox image to sleep 3 seconds and never restart
- Create a job with job.yaml `kubectl create -f job.yaml`
- Check job information:
  - `kubectl get job`
  - `kubectl describe job sleepy`
  - `kubectl get job sleepy -o yaml`
- Edit `job.yaml` by adding `completions: 5`
- Delete job `kubectl delete job sleepy` and recreate the job with `job.yaml`
- Do the same thing for `parallelism: 2`
- and `activeDeadlineSeconds: 15`
- Check the behavior of all these configurations
#### Create a CronJob
- Create `cronjob.yaml` based on `job.yaml`, and change the sleep seconds from 3 to 5
- Create the CronJob with cronjob.yaml `kubectl create -f cronjob.yaml`
- Check cronjob and job information:
  - `kubectl get cronjobs`
  - `kubectl get job`
- Add `activeDeadlineSeconds: 10` to `cronjob.yaml`
- Delete the old cronjob, recreate it with new yaml file, and watch the behavior
## 7 Managing State with Deployments
### 7.1 Working with ReplicaSets
- Create a ReplicaSet yaml file `rs.yaml`
  - name: rs-one
  - replicas: 2
  - label: ReplicaOne
  - image: nginx:1.11.1
- Create a ReplicaSet `rs-one` through yaml file `kubectl create -f rs.yaml`
- View the newly created ReplicaSet `kubectl describe rs rs-one`
- Delete the ReplicatSet without cascade (corresponding pods are not deleted) `kubectl delete rs rs-one --cascade=false`
- Create the ReplicaSet with the same yaml file again, and it will take ownership of those two pods
- Isolate one pod by editing its system label `kubectl edit pod <rs-pod-name>`
- Check the system label of all pods `kubectl get pod -L system`
- Delete the ReplicaSet and its pod `kubectl delete rs rs-one`
- The rs-one pod is deleted, and the isolated one is still running `kubectl get pod`
- Delete the isolated pod `kubectl delete pod -l system=IsolatedPod`
#### Remarks
- Here are the **watch loop** api objects which manage the state of containers in k8s:
  - **Replication Controller**: only manages container state
  - **ReplicaSet**: Replica Controller + selector
  - **Deployment**: ReplicaSet + rolling upgrade feature
  - **DaemonSet**: Similar with Deployment but DaemonSet ensures a pod will be created on each node of the cluster, including the newly added node
- ReplicaSet is the core api object that manage the state of containers in major k8s releases
### 7.2 Working with DaemonSets
- Create a DaemonSet yaml file `ds.yaml`
  - copy from rs.yaml
  - remove replicas line
  - change label from ReplicaOne to DaemonSetOne
- Create a DaemonSet based on ds.yaml `kubectl create -f ds.yaml`
- Watch the DaemonSet `kubectl get ds`
- Watch corresponding pods `kubectl get pod -o wide`
#### Remarks
- In DaemonSet yaml file, replicas is not needed, because each node would get one pod deployed
- Starting from k8s 1.12, user can configure certain nodes not to have a particular DaemonSet pods through scheduler
### 7.3 Rolling Updates and Rollbacks
#### DaemonSet UpdateStrategy: OnDelete (Delete pod, Create pod, Check change of new pod)
  - Edit the update strategy of DaemonSet to **OnDelete** `kubectl edit ds ds-one`
    - type: OnDelete
  - Set image of DaemonSet to a newer version `kubectl set image ds ds-one nginx=nginx:1.12.1-alpine`
  - Check the image version of corresponding pods `kubectl desrive pod <ds-one-pod-name> | grep Image:`
  - Delete one of the two pods belong to the DaemonSet
  - Check the image version of the old pod and the new pod to see the change
#### DaemonSet UpdateStrategy: OnDelete (Change to a version, Delete pod, Check change of new pod)
  - Check the change history for the DaemonSet `kubectl rollout history ds ds-one`
  - View the versions of the DaemonSet `kubectl rollout history ds ds-one --revision=<revision No.>`
  - Rollback to a version `kubectl rollout undo ds ds-one --to-revision=1`
  - Check the image version of pods
  - Delete one pod
  - Check the image version of both pods
#### DaemonSet UpdateStrategy: RollingUpdate
  - Export DaemonSet ds-one to yaml file ds2.yaml `kubectl get ds ds-one -o yaml --export >> ds2.yaml`
  - Change yaml file ds2.yaml
    - name: ds-two
    - type: RollingUpdate
  - Create DaemonSet ds-two based on the yaml file
  - Check all pods in default namespace `kubectl get pod`
  - Check the image version of a ds-two pod `kubectl describe pod <ds-two-pod-name> | grep Image:`
  - Edit ds-two and set a newer image version `kubectl edit ds ds-two`
    - image: nginx: 1.12.1-alpine
  - Check the age of DaemonSet ds-two `kubectl get ds ds-two`
  - Check the age of all pods in default namespace
  - Check the image version of one DaemonSet ds-two pod
  - Check the rollout status of DaemonSet ds-two `kubectl rollout status ds ds-two`
  - Check the rollout history of ds-two `kubectl rolloout history ds ds-two`
  - View the second version in the rollout history `kubectl rollout history ds ds-two --revision=2`
  - Clean up DaemonSets `kubectl delete ds ds-one ds-two`
#### Remarks
- Deployment has the same behavior in Rolling update and Rollback with DaemonSet
- Rolling update is one of the key benefit of using Microservice architure
## 8 Services
### Notes regarding Services Types
- **Cluster IP** = simplest service type
  - It provide a persistent access to pods which provide same function (pods can be up and down, therefore pod's IP address could be changed)
  - It is only routable within cluster (from pod or service), routing rules defined by iptables or ipvs
- **NodePort** = Cluster IP + Node Port
  - Main function is same as Cluster IP, but the service is exposed through a port of the node, therefore it can be accessed externally
- **LoadBalancer** = Cluster IP + Node Port + Load Balancer
  - In cloud (e.g. AWS), a Load Balancer will be created in front of the Node Port Service
  - Load Balancer charges customer additional cost, therefore NodePort should be used as much as possible if the access traffic is not high
- **ExternalName**
  - A special service type, map a service to a DNS CNAME record
  - It does not use Label to map corresponding pods like other service types
  - It just provide another DNS CNAME (e.g. my-service) to an existing service (e.g. my.database.example.com)
### 8.1 Deploy a New Service
- Create a deployment based on yaml file, which deploys two nginx server pods with spec.nodeSelector.system=secondOne
- After label one node with this label, pods can be created by the deployment `kubectl label node <node-name> system=secondOne`
- Then the pods can be accessed within cluster through <endpoint>:80
- **Remarks**: Actually no service has been created in this section
### 8.2 Configure a NodePort
- Expose the deployment through a service with type NodePort `kubectl -n <namespace> expose deployment nginx-one --type=NodePort --name=service-lab`
- **Remarks**: so far service has been created and can be accessed externally through the public IP address of any node
### 8.3 Use Labels to Manage Resources
- Delete the deployment using its labels `kubectl -n <namespace> delete deploy -l system=secondary`
- Remove teh lable from the secondary node `kubectl label node <node-name> system-`
## 9 Volumes and Data
### 9.1 Create a ConfigMap
- ConfigMap is a set of key value pairs
- ConfigMap can be created from a literal value or a file or a directory which contains files `kubectl create configmap colors --from-literal=text=black --from --file=./favorite --from-file=./primary/`
- ConfigMap can be used to create env of a pod
- ConfigMap can also be used to create a volume of a pod
### 9.2 Creating a Persistent NFS Volume (PV)
- Deploy an NFS server (package nfs-kernel-server) on k8s master node
- Create file `/opt/sfw/hello.txt` and export them through NFS
- Install package nfs-common on the worker node and mount the `/opt/sfw` dir to `/mnt` to test wheter NFS works
- Create a PV with **1Gi** capacity and this NFS path `/opt/sfw` on k8s master node `kubectl create -f PVol.yaml`
- Check the status of the PV `kubectl get pv`, which should be `Available`
### 9.3 Creating a Persistent Volume Claim (PVC)
- To use the newly created PV, a PVC (request **200Mi** storage) needs to be created `kubectl create -f pvc.yaml`
- The status of the PV becomes `Bound`
- Create a pod which uses the PVC by specifying it in `spec.template.spec.volumes`
- Check the status of the PVC `kubectl get pvc`
### 9.4 Using a ResourceQuota to Limit PVC Count and Usage
- Create a namespace called `small` to test the ResourceQuota and ResourceLimit `kubectl create namespace small`
- Create the PV and PVC in this namespace
- Create a ResourceQuota object with a storage quota of **500Mi** `kubectl create -f storage-quota.yaml`
- Check the resource quota of this namespace (Used 200Mi, Hard 500Mi) `kubectl describe ns small`
- Create a pod under this namespace and check the status of the pod and the resrouce quota of the namespace (should have no change)
- Create a 300M file in `/opt/sfw` and check the resource quota of the namespace (should have no change)
- Delete the PVC and check the status of the PV (should become Released)
- Delete the PV
- Recreate the PV and patch the `persistentVolumeReclaimPolicy` to `Delete`
- Check the status of the namespace (Used 0, Hard 500Mi)
- Recreate the PVC (Used 200Mi, Hard 500Mi)
- Delete the ResourceQuota from the namespace and change to a smaller quota (requests.storage: "100Mi")
- Recreate the ResourceQuota to the namespace and check the status of the namespace (**Used 200Mi, Hard 100Mi**)
- Check the status of the deployment and the pod (both works fine)
- Remove the deployment and delete the PVC to test whether the reclaim of storage takes place
- Check the status of the PV and it did not happen because it is lack of a **deleter volume plugin** for NFS
- Delete the PV as well
- Change the PV property `persistentVolumeReclaimPolicy` to `Recycle`
- Add a LimitRange to the namespace `kubectl -n small create -f low-resource-range.yaml` and check the status of the namespace
- Create the PV again and check its status (Reclaim Policy: Recycle, Status: Available)
- Create the PVC and it would fail (**ResourceQuota only works together with Resource Limits**)
- Edit the ResourceQuota and raise it to 500Mi
- Create the PVC and Deployment, and now it works
- Delete the PVC and PV
## 10 Ingress
### 10.1 Advanced Service Exposure (Configure an Ingress Controller)
- Deploy an NGINX deployment named `secondapp` and expose its service with type NodePort (`secondapp` is a backend service of the ingress)
- Create `ClusterRole` and `ClusterRoleBinding` of ingress controller with file `ingress.rbac.yaml`
- Create `serviceaccount, daemonset, and service` of ingress controller with file `traefik-ds.yaml`
- Create `ingress` (ingress rule) with file `ingress.rule.yaml`
- Test the ingress with command `curl -H "Host: www.example.com" http://k8smaster/`
- Deploy another NGINX deployment named `thridpage` and also expose its service with type NodePort
- Edit `ingress` to add the rule for `thirdpage`
- Log into the pod and change the title of the thirdpage NGINX homepage to `Third Page` and the domain name to `thirdpage.org`
- Test the ingress with command `curl -H "Host: thirdpage.org" http://k8smaster/`
- `http://<public ip>:8080` can be used to check the traefik dashboard
### Remarks:
- Ingress basically provides three functions: SSL termination, Layer 7 routing(e.g. path-based routing), and Load Balancing (done together with load balancer)
- The core of an ingress controller is Deployment(or Daemonset) and Service(usually with type Load Balancer)
- Ingress resource defines the routing rules (normally is path-based), and it is implemented by the pods of ingress controller when the ingress resource yaml file is applied
- Ingress does not have to be used together with a load balancer. The above case is an example. Basically ingress is just an entrypoint which takes the request from client and routes it to the target service based on the host name or path (i.e. L7 routing). However, Ingress is usually used together with a Load Balancer in front of it
- Ingress controller can be used together with either L4 or L7 load balancer
- In the case of L4 load balancer, path-based routing is done by ingress controller, as the L4 load balancer simply forwards the packet from client to the backend service. It may do NAT to replace the source and destination IP address of the packet, but it would not look into the content of the packet
- It is better to use an ingress-native L7 load balancer (i.e. ingress controller is embedded as a component of the L7 load balancer, e.g. ALB in AWS). In this case, this load balancer can consider factors of both node workload and service target when making dispatch decision. As the L7 load balancer would terminate the http connection and look into the content, the dispatch cost is usually higher than L4 load balancer. Therefore, if an L7 load balancer (e.g. ELB in AWS) could not embed ingress L7 routing rules, it would then leave the path-based routing task to the ingress controller in the k8s cluster, which would cost additional resources in the cluster and may require one more hop to the node where the backend pod locates
- client -> L4 Load Balancer or common L7 Load Balancer (workload-based dispatching) -> ingress controller (path-based dispatching) -> backend service
- client -> ingress-native L7 Load Balancer (workload-based and path-based dispatching) -> backend service
- [A blog describrs NLB + NGINX ingress controller and compares this option with ALB](https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/)
## 11 Scheduling
### 11.1 Assign Pods Using Labels
- Check labels and taints of cluster nodes `kubectl describe nodes | grep -i label` `kubectl describe nodes | grep -i taint`
- Check number of docker containers in both nodes `sudo docker ps | wc -l`
- Add different labels to master node and worker node `kubectl label nodes <master> status=vip` `kubectl label nodes <worker> status=other`
- Show labels of the two nodes `kubectl get nodes --show-labels`
- Create `vip.yaml` which defines one pod that has 4 busybox containers with `nodeSelector.status=vip`
- Apply `vip.yaml` and check the number of docker containers on both nodes (vip pod should be all deployed on master node)
- Delete the vip pod and edit vip.yaml to comment out the nodeSelector.status part
- Apply vip.yaml again and check the number of docker containers again (vip pod is deployed on worker node to make the cluster more balanced)
### 11.2 Using Taints to Control Pod Deployment
- Create a Deployment file named `taint.yaml` which deploys 8 pod, each has one nginx container
- Apply taint.yaml and count containers (pods should be deployed more or less evenly on the 2 nodes)
- Delete the deployment and taint the worker node with value `PreferNoSchedule` `kubectl taint nodes <worker> bubba=value:PreferNoSchedule` (The key, bubba, can be any word)
- Apply taint.yaml and count containers (most of the pods should be on master, however a few are deployed on worker)
- Delete the deployment and taint the worker with value `NoSchedule` `kubectl taint nodes <worker> bubba=value:NoSchedule` 
- Apply taint.yaml and count containers (All of the pods are deployed on master)
- Delete the deployment and untaint `kubectl taint nodes <worker> bubba-`
- Apply taint.yaml and count containers (back to the first status, i.e. pods should be deployed more or less evenly on the 2 nodes)
- Taint the worker node with `NoExecute` `kubectl taint nodes <worker> bubba=value:NoExecute`
- Wait a minute and count containers (nearly all pods on worker move to the master node, including the ones which are not deployed by taint.yaml. Only a few in namespace kube-system are left on worker node, which are responsible for communication with the cluster)
- Remove the taint, wait a minute, and count containers (most containers still reside in master node)
- Drain the worker node `kubectl drain <worker>`
- Check the status of nodes `kubectl get nodes` (Status of worker node becomes Ready.SchedulingDisabled)
- Delete the deployment, apply taint.yaml, and count containers (nginx pods are all deployed to master node)
- Uncordon the worker node `kubectl uncordon <worker>` and check status of nodes (work node back to Ready)
- Delete the deployment, apply taint.yaml, and count contaienrs (container spread across the cluster, master has a few more due to its role)
## 12 Logging and Troubleshooting
### 12.1 Review Log File Locations
#### If k8s is based on systemd,
- check node level logs for kubelet `journalctl -u kubelet`
- Locate kube-apiserver log file `sudo find / -name "*apiserver*log"`
  - container log is identical to pod log, as it is a symbolic link to pod log
  - use similar command to locate log file of `kube-dns, kube-flannel, kube-proxy`
#### If k8s is not based on systemd,
- [Master]
  - `/var/log/kube-apiserver.log`
  - `/var/log/kube-scheduler.log`
  - `/var/log/kube-controller-manager.log`
  - `/var/log/containers/`
  - `/var/logpods/`
- [Worker]
  - `/var/log/kubelet.log`
  - `/var/log/kube-proxy.log`
#### More readings
- [Debug service](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/)
- [Determine reason pod failure](https://kubernetes.io/docs/tasks/debug-application-cluster/determine-reason-pod-failure/)
### 12.2 Viewing Logs Output
- View pod logs `kubectl -n <namespace> logs <pod name>`
- The infrastructure pods are under `kube-system` namespace
### 12.3 Adding tools for monitoring and metrics
#### Configure Metrics
- Download **Metrics Server** `git clone https://github.com/kubernetes-incubator/metrics-server.git`
- Create metrics server object `kubectl create -f metrics-server/deploy/kubernetes/`
- Check metrics server pods `kubectl -n kube-system get pods`
- Disable secure TLS for this lab environment
  - `kubectl -n kube-system edit deployment metrics-server`
  - Add this line to container's args `- --kubelet-insecure-tls`
- Test the metrics working
  - `kubectl top pod --all-namespaces`
  - `kubectl top nodes`
- Metrics server's http path in apiserver `https://k8smaster:6443/apis/metrics.k8s.io/v1beta1/nodes`
- **Heapster** is deprecated, and **Metrics Server** has been further developed and deployed
- Metrics server is written to interact with Docker, and it does not support crio
#### Configure the Dashboard
- Create dashboard object `kubectl create -f https://bit.ly/2OFQRMy`
- Check dashboard service `kubectl get svc --all-namespaces`
- Change the `'kubenetes-dashboard` service type to `NodePort`
  - `kubectl -n kubernetes-dashboard edit svc kubernetes-dashboard`
  - Edit type from `ClusterIP` to `NodePort`
- Check the service again and write down the port number
- Create clusterrolebinding to avoid RBAC and other permission error `kubectl create clusterrolebinding dashaccess --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:kubernetes-dashboard`
- Open browser and use `https://<public IP>:<dashboard service port>` to access dashboard
- Since a self-signed certificate is not trusted by Chrome, you need to play some trick to let chrome trust it:
  -[Windows] add exception, add trusted site
  -[MacOS Catalina] type `thisisunsafe` in the Chrome window, or check [this link](https://vninja.net/2019/12/03/macos-catalina-chrome-cert-issues/) for other tricks
- Get the token of dashboard `kubectl -n kubernetes-dashboard describe secrets kubernetes-dashboard-token-<press tab to auto complete the secret name>`
- Paste token to the browser and you should be able to see the dashboard
#### Remarks
- Dashboard must be based on a "real" monitoring/metrics object, which is Metrics Server in this case
- Dashboard is only updated with Metrics Server, as Heapster is deprecated
- Dashboard does not provide full functionality of Metrics Server
## 13 Custom Resouce Definition
### 13.1 Create a Custom Resource Definition
- Create `crd.yaml` file which defines a new custom resource named `crontabs.training.com` with `spec.names.kind=CronTab`
- Apply crd.yaml to add the new resource to the cluster (a resource is a k8s API object type, like pod, deployment, service)
- List all the custom resource in the cluster `kubectl get crd`
- Describe the newly added custom resource `kubectl describe crd crontabs.training.com`
- Add one object of the new API resource by creating file `new-crontab.yaml` (which is like to create a pod yaml file)
- Apply new-crontab.yaml (which is like to create a pod) `kubectl create -f new-crontab.yaml`
- List CronTab objects `kubectl get CronTab` `kubectl get ct` (ct is short name for CronTab)
- Command like `describe` `delete` can also be used on custom resource
## 14 Helm
### 14.1 Working with Helm and Charts
- Download helm executable `wget https://get.helm.sh/helm-v3.0.0-linux-amd64.tar.gz`
- Uncompress it `tar -xvf ...` and copy the files to /usr/local/bin `sudo cp linux-amd64/helm /usr/local/bin/helm3`
- Search database helm chart from helm hub `helm3 search hub database`
- Add the most common helm repository and name it as stable `helm3 repo add stable https://kubernetes-charts.storage.googleapis.com`
- Update the repo `helm3 repo update`
- Install mariadb with name `firstdb` through corresponding helm chart in this repo `helm3 --debug install firstdb stable/mariadb --set master.persistence.enabled=false --set slave.persistence.enabled=false` (do not need persistence to avoid creating a PV)
- Use the command in the output from the last command to get root password
- Also use the output to run and logon a client pod of the mariadb
- Use the output to test mariadb
- Exit the client pod
- View the Chart history `helm3 list -a`
- Delete the mariadb chart `helm3 uninstall firstdb`
- Find the chart of mariadb `find ~ -name *mariadb*`
- Uncompress the mariadb chart
- Copy the value.yaml to custom.yaml, and change the rootUser password and change value of persistence to false
- Install another mariadb named `seconddb` with the custom.yaml file `helm3 install seconddb -f custom.yaml stable/mariadb`
- Use the output of last command to run mariadb client pod and test the second mariadb
### Remarks
- Helm is the package manager of Kubernetes
- One application has one chart that describes its components (e.g. deployment, service, serviceaccount..) and dependencies (i.e. sub-chart)
- The components are defined as yaml files in **templates** folder
- **Chart.yaml** defines the metadata (e.g. name and version of the application)
- **Value.yaml** defines the variables which may be used by multiple files in the template folder (e.g. container port may be used by both of deployment and service)
- Charts are normally collected in helm repositories (like git repository) or helm hub (like docker hub). Normally user should search in helm hub through command `helm3 search hub` to find the chart of the needed application and then download the repository through command `helm repo add` or install it through `helm install`
- [Create your first helm chart](https://docs.bitnami.com/tutorials/create-your-first-helm-chart)
## 15 Security
### 15.1 Working with TLS
- Look for `--config` file from the output of `systemctl status kubelet.service`
- Look for `staticPodPath` from the config.yaml file found in the kubelet config file
- Certificate info can be found in the yaml files from the staticPodPath, including etcd, apiserver, scheduler, controller manager and so on
- Check tokens from secrets `kubectl -n kube-system get secrets` `kubectl -n kube-system get secrets certificate-controller-token -o yaml`
- Access config of k8s cluster can also be checked via `kubectl config view` and set by `kubectl config set-credentials -h`
- Other useful commands can be checked via `kubectl config <Tab><Tab>`
- `sudo kubeadm config -h` is also a way to check k8s cluster config `sudo kubeadm config print init-defaults`
- Backup the access config file so as to compare it with a change in the next section `cp ~/.kube/config ~/cluster-api-config`
### 15.2 Authentication and Authorization
- Create two namespaces `development` and `production`
- View the current context `kubectl config get-contexts`
- Create a new user in OS `sudo useradd -s /bin/bash DevDan` `sudo passwd DevDan`
- Generate a private key and a Certificate Signing Request(CSR) for DevDan using openssl
- Generate a Certificate based on the private key and CSR using openssl
- Upadate the access config file to reference the new key and certificate `kubectl config set-credentials DevDan --client-certificate=/home/student/DevDan.crt --client-key=/home/student/DevDan.key`
- Compare the config file with the backup `diff cluster-api-config ~/.kube/config`
- Create a context for user DevDan in development namespace `kubectl config set-context DevDan-context --cluster=kubernetes --namespace=development --user=DevDan`
- List the pods in this context (should fail due to lack of authorization) `kubectl --context=DevDan-context get pods`
- List the contexts `kubectl config get-contexts`
- Create a yaml file for Role `kubectl create -f role-dev.yaml`
- Create a yaml file for Rolebinding `kubectl apply -f rolebind.yaml`
- Create a deployment in the development context `kubectl --context=DevDan-context create deployment nginx --image=nginx`
- List the pods in this context again (should see one pod now)
- Delete the deployment in this context `kubectl --context=DevDan=context delete deploy nginx`
- Copy and edit the yaml file for Role and Rolebinding for production namespace, take the `create` verb out
- Apply these two yaml files for user DevDan in production namespace `kubectl config set-context ProdDan-context --cluster=kubernetes --namespace=production --user=DevDan`
- List the pods in the production context (should be successful, but there is no pod) `kubectl --context=ProdDan-context get pods`
- Create a deployment in the production context `kubectl --context=ProdDan-context create deployment nginx --image=nginx` (Should fail due to lack of authorization)
- View the details of the role `kubectl -n production describe role dev-prod`
### 15.3 Admission Controllers
- How to check the admission controller settings `sudo grep admission /etc/kubernetes/manifests/kube-apiserver.yaml`
## 16 High Availability
### Prepare more nodes
- Create three more nodes: Proxy(Load Balancer), Second Master, Third Master
### Deploy a Load Balancer
- Install an open source tool HAProxy `sudo apt-get install -y haproxy`
- Edit the HAProxy configuration file `sudo vim /etc/haproxy/haproxy.cfg`
  - change from http to tcp
  - add three master nodes' info
- Restart the HAProxy service `sudo systemctl restart haproxy.service`
- Edit /etc/hosts on master node, change the IP of k8smaster from the master's IP to proxy's IP
- Open browser to test proxy server `http://<proxy public ip>:9999/stats`
### Install Software
- Copy and execute script `k8s_master_ha_init.sh` to install k8s softwares on second master and third master
### Join Master Nodes
- Edit /etc/hosts on second and thrid master, make sure the hostname `k8smaster` is corresponding to the proxy's IP
- On master node, use command `kubeadm token create --print-join-command` to get the join command for second and third master
- Also on master node, get the master certificate by running command `sudo kubeadm inti phase upload-certs --upload-certs`
- On second and third master, run this command to join them as master role to the k8s cluster `sudo kubeadm join k8smaster:6443 --token <token> --discovery-token-ca-cert-hash <hash> --control-plane --certificate-key <certificate key>
- On proxy node, uncomment the lines for second and third master in the HAProxy configuration file
- Restart HAProxy `sudo systemctl restart haproxy.service`
- Check status again through proxy's web page
- Check the etcd pod name and logs
  - `kubectl -n kube-system get pods | grep etcd`
  - `kubectl -n kube-system logs -f etcd-<any master>`
- Execute this command in any etcd pod to check the cluster status (e.g. who IS LEADER)
  - `kubectl -n kube-system exec -it etcd-<any master> -- /bin/sh`
  - `ETCDCTL_API=3 etcdctl -w table --endpoints <first master>:2379,<second master>:2379,<thrid master>:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key endpoint status`
  ### Test Failover
  - Shut down the docker service on the node which shows IS LEADER = true `sudo systemctl stop docker.service`
  - Check the etcd logs and the HAProxy web page (should see the previous leader is down now)
  - Check the cluster status by executing the command in last section in the etcd pod
  - Start the docker service again
  - Checke the etcd logs, HAProxy web page, and the cluster status from etcd pod


