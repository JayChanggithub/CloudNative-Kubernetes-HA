CloudNative-kubernetes-HA
===========================


> kubernetes: [high-availability](https://www.kubeclusters.com/docs/How-to-Deploy-a-Highly-Available-kubernetes-Cluster-with-Kubeadm-on-CentOS7)


---

## Version

`Rev: 1.0.2`

---

# Suitable Project

  - `none`

---

## Status

[![pipeline status](http://ipt-gitlab.ies.inventec:8081/SIT-develop-tool/CloudNative-Kubernetes-HA/badges/master/pipeline.svg)](http://ipt-gitlab.ies.inventec:8081/SIT-develop-tool/CloudNative-Kubernetes-HA/commits/master)

## Description

   - Using automation management tool `ansible-playbook` to deploy kubernetes HA cluster.
   - Kubernetes version **`v1.15.1`**

---

## prerequisites

  - The control machine which could command remote nodes the must be have `ansible`.
  - Cluster quantity must be `3`.
  - Only support operation system `centos 7.x`.
  - Edit `./variables/common.yaml` following block
      - **define masters hostname**
      - **define ip address**
      - **interface**
  - Edit `./inventory` whole of nodes information

---

## Usage

   - Deployment the kubernetes HA cluster

     ```bash
     $ ansible-playbook -i inventory setup.yaml
     ```

   - Destroy the kubernetes cluster

     ```bash
     $ ansible-playbook -i inventory reset.yam
     ```

---

## Trouble shooting

   - Detected the VIP

     ```bash
     $ nc -v $vip $port
     ```

   - Verify the etcd connection

     ```bash
     $ etcdctl --ca-file=/etc/etcd/pki/ca.pem --cert-file=/etc/etcd/pki/server.pem --key-file=/etc/etcd/pki/server-key.pem --endpoints=https://$node_ip:2379 cluster-health
     ```

   - Detected the ansible yaml syntax

     ```bash
     $ ansible-playbook -i inventory --syntax-check <ansible.yaml>
     ```

   - Inspect the kubernetes routing mode

     - **iptables**(default)

       ```bash
       $ iptables -t nat -nvL KUBE-NODEPORTS
       ```

     - **ipvs**

       ```bash
       $ ipvsadm -Ln
       ```

   - Showing the local route tables

     ```bash
     $ ip route show table local type local proto kernel
     ```

   - The following container network error occurred

     **`NetworkPlugin cni failed to set up pod, '*****' network: failed to set bridge addr: 'cni0' already has an IP address different from '****'`**

     ```bash
     $ systemctl stop docker
     $ ip link set cni0 down
     $ brctl delbr cni0
     $ systemctl restart docker
     ```

   - Inspect the kube-proxy mode

     ```bash
     $ kubectl get configmaps kube-proxy -n kube-system -o yaml | awk '/mode/{print $2}'
     ```

   - Encountered the following info about kubernetes network service port.

     **`The Service "my-nginx" is invalid: spec.ports[0].nodePort: Invalid value: 80: provided port is not in the valid range. The range of valid ports is 30000-32767`**

     ```bash
     $ vim /etc/kubernetes/manifests/kube-apiserver.yaml
     ```

     ```yml
     spec:
       containers:
         - command:
            - kube-apiserver
            ...
            ...
            - --service-node-port-range=1-65535
     ```

     ```bash
     $ systemctl daemon-reload && systemctl restart kubelet
     ```

   - Encountered the following info about kubernetes dashboard.

     **`configmaps is forbidden: User "system:serviceaccount:kube-system:kubernetes-dashboard" cannot list configmaps in the namespace "default"`**

     - Method 1

       ```bash
       # create the admin user for dashboard
       $ kubectl create clusterrolebinding add-on-cluster-admin \
                 --clusterrole=cluster-admin \
                 --serviceaccount=kube-system:kubernetes-dashboard
       ```

      - Method 2

        ```yml
        # kube-dashboard-access.yaml
        apiVersion: rbac.authorization.k8s.io/v1beta1
        kind: ClusterRoleBinding
        metadata:
        name: kubernetes-dashboard
        labels:
          k8s-app: kubernetes-dashboard
        roleRef:
          apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: cluster-admin
        subjects:
         - kind: ServiceAccount
           name: kubernetes-dashboard
           namespace: kube-system
        ```

        ```bash
        $ kubectl apply -f kube-dashboard-access.yaml
        ```

## Contact

##### Author: Jay.Chang

##### Email: chang.jay@inventec.com