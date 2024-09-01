#!/bin/sh
#############################################################
#      Copyright (C) 2024        josopo                     #
#############################################################

#Some variables to change

KUBEADM_VERSION="v1.29" # Select the kubeadm version to install
CALICO_VERSION="v3.28.1" #Select the version of Calico
KUBE_PODS_CIDR="192.168.100.0/24" #IP range the pods will take inside the cluster
CRI_SOCKET="unix:///var/run/containerd/containerd.sock" #socket to use
SLEEP=1

######################################
#Disable SWAP Memory in all nodes
sudo swapoff -a
sudo sed -e '/\/swap\/.* swap /s/^/#/' /etc/fstab

echo "SWAP MEMORY DISABLED..........."

######################################

#(Optional) Change hostname name to "master-mode"
sudo hostnamectl set-hostname "master-node" && exec bash

HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -i)

# (Optional) In case you dont have a DNS server use the /etc/hosts file of each node to connect with each node by domaine name instead of the IP
# Check if the IP address is already in /etc/hosts
if grep -q "$IP_ADDRESS" /etc/hosts; then
    echo "IP address already exists in /etc/hosts."
else
    # Add the IP address and hostname to /etc/hosts
    echo -e "$IP_ADDRESS\t$HOSTNAME" | sudo tee -a /etc/hosts
    echo "Added $IP_ADDRESS $HOSTNAME to /etc/hosts."
fi

sleep $SLEEP
######################################

#Set up the IPV4 bridge
#Enalbe overlay and bridge modules to the kernel

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay && sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
sleep $SLEEP
######################################

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Check if the directory exists
if [ ! -d "/etc/apt/keyrings" ]; then
    # Create the directory if it doesn't exist
    sudo mkdir -p /etc/apt/keyrings
fi

curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBEADM_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBEADM_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sleep $SLEEP

#Test version
sudo kubectl version --client && sudo kubeadm version
######################################

#Install containerd

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sleep $SLEEP
#Configure a valid config.toml file

sudo mkdir -p /etc/containerd
sudo sh -c "containerd config default > /etc/containerd/config.toml"
sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd.service
sudo systemctl restart kubelet.service
sleep $SLEEP
######################################
#Initialize the Kubernetes cluster on the master node

sudo kubeadm config images pull
sleep $SLEEP
#In case you use a DNS server use the DNS record asigneed to the master node for the '--control-plane-endpoint' argument
sudo kubeadm init --pod-network-cidr=$KUBE_PODS_CIDR --cri-socket=$CRI_SOCKET --upload-certs --control-plane-endpoint=$HOSTNAME
sleep $SLEEP
######################################

#Add the .kube to the home folder directory where we can make request to the KUBERNETES API

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG= $HOME/.kube/config

######################################

#Configure kubectl and Calico CNI v3.26.4
curl -O https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml
curl -O https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml

kubectl create -f tigera-operator.yaml
sed -ie "s|192.168.0.0/16|$KUBE_PODS_CIDR|g" custom-resources.yaml
kubectl create -f custom-resources.yaml
sleep 10
######################################
