#!/bin/bash

# define globals variables
NC1='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CWD=$PWD
revision=$(grep 'Rev:' ../README.md | grep -Po '(\d+\.){2}\d+')
__file__=$(basename $0)
logdir='../reports'
log_name=$(basename $__file__ .sh).log

function reset
{
    local count=0
    local f_list=('/etc/kubernetes'
                  '/var/lib/etcd'
                  '/var/lib/kubelet'
                  '/var/lib/cni/'
                  '/etc/cni/net.d/'
                  "$HOME/.kube/")


    if [ "$(kubectl get configmaps kube-proxy -n kube-system -o yaml \
         | awk '/mode/{print $2}' > /dev/null 2>&1)" != "ipvs" ]; then
        iptables -F
        iptables -t nat -F
        iptables -t mangle -F
        iptables -X
    else
        ipvsadm --clear
    fi

    # stop kubelet service
    kubeadm reset --force > /dev/null 2>&1
    systemctl daemon-reload
    systemctl stop kubelet
    systemctl stop docker
    systemctl stop etcd

    # delete network bridge
    if [ -n "$(ifconfig -a | grep -E 'cni0|flannel.1')" ]; then
        ifconfig cni0 down
        ifconfig flannel.1 down
        ip link delete cni0
        ip link delete flannel.1
    fi

    # check whether empty
    for d in ${f_list[@]}
    do
        if [ -n "$(ls $d)" ]; then
            rm -rf ${d}/*
        fi
    done

    systemctl daemon-reload
    systemctl restart docker

    # clean up docker process cache
    if [ $(docker ps -a -q -f "status=exited" | wc -l) -ne 0 ]; then
        printf "%s\t%30s${YELLOW} %s ${NC1}]\n" \
               " Starting clear 'Exited' containers...,   " "[" "okay." \
               | sed -E s',^ ,,'g
        docker rm $(docker ps -a -q -f "status=exited")
    fi

    # clean up the docker images cache
    if [ $(docker images -f "dangling=true" -q | wc -l) -ne 0 ]; then
        printf "%s\t%30s${YELLOW} %s ${NC1}]\n" \
               " Starting clear 'Untagged/Dangling' images...,   " "[" "okay." \
               | sed -E s',^ ,,'g
        docker image rmi $(docker images -f "dangling=true" -q)
    fi

    if [ $? -eq 0 ]; then
        printf "%s\t%30s${YELLOW} %s ${NC1}]\n" \
               " Kubernetes service clean done,   " "[" "okay." \
               | sed -E s',^ ,,'g
        printf "%s\t%30s${YELLOW} %s ${NC1}]\n" \
               " Clear docker cache done,   " "[" "okay." \
               | sed -E s',^ ,,'g
    fi
}

function main
{
    reset
}

main | tee ${logdir}/${log_name}
