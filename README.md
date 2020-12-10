CloudNative-kubernetes-HA
===========================

> kubernetes: [high-availability](https://www.kubeclusters.com/docs/How-to-Deploy-a-Highly-Available-kubernetes-Cluster-with-Kubeadm-on-CentOS7)

---

## Version

`Rev: 1.0.9`

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
  - The `kube` packages version **1.15.1**

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

   - Use Ansible container to execute

     ```bash
     $ docker run --rm --name ansible-tool -v $(pwd):/srv/lib -v $(pwd)/inventory:/etc/ansible/hosts registry.ipt-gitlab:8081/sit-develop-tool/tool-ansible:1.0.1 bash -c "ansible-playbook -i /etc/ansible/hosts reset.yaml"
     ```

---

## Trouble shooting

   - Inspect the kube-proxy configmap configuration

     ```bash
     $ kubectl edit cm kube-proxy -n kube-system
     ```

   - Delete the kube-ipvs0 network

     ```bash
     $ nmcli dev delete kube-ipvs0
     $ ip addr del ${node_ip}/32 dev kube-ipvs0
     ```

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

   - The connection to the server localhost:8080 was refused - did you specify the right host or port?

     ```bash
     $ mkdir -p $HOME/.kube
     $ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
     $ sudo chown $(id -u):$(id -g) $HOME/.kube/config
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

   - Multi network interface

     ```bash
     $ vim kube-flannel.yaml

     containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.11.0-s390x
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        - --iface=<iface>
     ```

   - Bare metal use Ingress + MetalLB Load Balancer service type

     - Setup metalLB deployment

       ```bash
       $ vim ./plugin/metailb/metailb-conf.yaml
       ```

       ```yaml
       apiVersion: v1
       kind: ConfigMap
       metadata:
         namespace: metallb-system
         name: config
       data:
         config: |
           address-pools:
           - name: production
             protocol: layer2
             addresses:
             # <IP range the same as your cluster>
             - 192.168.44.1-192.168.44.4
       ```

       ```bash
       $ kubectl apply -f ./plugin/metailb/metailb-namespace.yaml
       $ kubectl apply -f ./plugin/metailb/metailb.yaml

       # On first install only
       $ kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
       $ kubectl apply -f ./plugin/metailb/metailb-conf.yaml
       ---

     - setup the ingress configuration

       ```bash
       $ vim ./plugin/ingress_controller/ingress-svc.yaml
       ```

       ```yaml
       metadata:
         name: ingress-nginx
         annotations:
           metallb.universe.tf/address-pool: production

       ...
       ...
       spec:
         externalIPs:
         - master1_ip
         - master2_ip
         - master3_ip
         - vip
       type: LoadBalancer

       ```

     - Setup any service if you want type as **`'LoadBalancer'`**

       ```yaml
       annotations:
         metallb.universe.tf/address-pool: production
         kubernetes.io/ingress.class: "nginx"

       ...
       ...

       spec:
         type: LoadBalancer
       ```

     - Encountered the CNI flannel **`vxlan_network.go:158] failed to add vxlanRoute (***** -> **** ): invalid argument`**

       ```bash
       # step 1 check flannel process then inspect flannel subnet configuration

       $ docker ps | grep flanneld
       $ docker logs 44465a91c2d3
       $ kubectl logs flanneld-**** -n kube-system

       $ cat /run/flannel/subnet.env

       # output
       FLANNEL_NETWORK=10.42.0.0/16
       FLANNEL_SUBNET=10.42.1.1/24
       FLANNEL_MTU=1450
       FLANNEL_IPMASQ=true
       ---

       # step 2 discoverd the network conflict
       $ kubeadm reset
       $ systemctl stop kubelet
       $ systemctl stop docker
       $ rm -rf /var/lib/cni/
       $ rm -rf /var/lib/kubelet/*
       $ rm -rf /etc/cni/
       $ ifconfig cni0 down
       $ ifconfig flannel.1 down
       $ ifconfig docker0 down
       $ ip link delete cni0
       $ ip link delete flannel.1

       # restart kubelet
       $ systemctl restart kubelet

       # restart docker
       $ systemctl restart docker
       ```

     - Verify `coredns` resolve function

       ```bash
       $ kubectl run curl --image=radial/busyboxplus:curl -it
       
       # 可以使用下列形式; 以 svc 為例
       $ nslookup <service-name>.<namespace-name>.svc.cluster.local
       $ nslookup kubernetes.default

       ---
       output:

       Server:    10.96.0.10
       Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

       Name:      kubernetes.default
       Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
       ```

## Contact

##### Author: Jay.Chang

##### Email: cqe5914678@gmail.com
