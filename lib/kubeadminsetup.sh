#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[0;33m'
NC1='\033[0m'
__file__=$(basename $0)
log_name=$(basename $__file__ .sh).log
logdir='../reports'
revision="$(grep 'Rev:' ../README.md | grep -Eo '([0-9]+\.){2}[0-9]+')"

function k8smasternode
{
    kubeadm init --config=${kubadm_init_file} --upload-certs

    if [ -f /var/lib/kubelet/config.yaml ]; then
        sed -i 's,^cgroupDriver\:\ cgroupfs,cgroupDriver\:\ systemd,g' \
        /var/lib/kubelet/config.yaml
    fi

    if [ $? -eq 0 ]; then
        export KUBECONFIG=/root/.kube/config
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        if [ $(cat /root/.bash_profile | grep -ci '(kubectl completion bash)') -ne 1 ]; then
            echo "source <(kubectl completion bash)" >> ~/.bash_profile
            source ~/.bash_profile 
        fi

        # could invoke the pods in master node
        kubectl taint nodes --all node-role.kubernetes.io/master-
        systemctl daemon-reload
        systemctl start kubelet
    fi

    # change node port range to 1-65535
    if [ -f /etc/kubernetes/manifests/kube-apiserver.yaml ]; then
        if [ $(cat /etc/kubernetes/manifests/kube-apiserver.yaml | \
                grep -ci 'service-node-port-range') -eq 0 ]; then
            sed -i \
                -E \
                "35a\    -\ --service-node-port-range=1-65535" \
                /etc/kubernetes/manifests/kube-apiserver.yaml
            systemctl daemon-reload && systemctl restart kubelet
        fi
    fi
}

function main 
{
    k8smasternode
}

if [ "$#" -eq 0 ]; then
    printf "%s\t%30s${RED} %s ${NC1}]\n" \
           " Invalid arguments,   " \
           "[" "arguments is empty."
    exit 1
fi

while [ "$1" != "" ]
do
    case "$1" in
        -v|--version)
            printf "${YELLOW} %s ${NC1}\n" \
                   "$__file__  version: ${revision}" \
                   | sed -E s',^ ,,'g
            exit 0
            ;;
        -f|--file)
            shift
            kubadm_init_file=$1
            ;;
        *)
            printf "%s\t%30s${RED} %s ${NC1}]\n" \
                   " Invalid arguments,   " \
                   "[" "arguments is invalid."
            exit 1
            ;;
    esac
    shift
done

main | tee ${logdir}/${log_name}
