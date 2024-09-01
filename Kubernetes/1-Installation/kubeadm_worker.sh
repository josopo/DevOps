#!/bin/sh
###############################################################
#      Copyright (C) 2024        josopo                       #
###############################################################

#Some variables to change

KUBEADM_VERSION="v1.29"
KUBE_PODS_CIDR="192.168.10.0/24"
CRI_SOCKET="unix:///var/run/containerd/containerd.sock"
SLEEP=1

######################################
#Disable SWAPOFF
sudo apt-get update

sudo swapoff -a
sudo sed -e '/\/swap\/.* swap /s/^/#/' /etc/fstab

echo "SWAP MEMORY DISABLED..........."
######################################
#If you have a DNS server available you can remove this part. Set the IP to your DNS server
#Change hostname name to "master-mode"
sudo hostnamectl set-hostname "worker-node" && exec bash

HOSTNAME="master-node"
IP_ADDRESS=0.0.0.0 #Set here your master node IP

# (Optional) In case you dont have a DNS server use the /etc/hosts file of each node to connect with each node by domaine name instead of the IP

# Check if the IP address is already in /etc/hosts
if grep -q "$IP_ADDRESS" /etc/hosts; then
    echo "IP address already exists in /etc/hosts..........."
else
    # Add the IP address and hostname to /etc/hosts
    echo -e "$IP_ADDRESS\t$HOSTNAME" | sudo tee -a /etc/hosts
    echo "Added $IP_ADDRESS $HOSTNAME to /etc/hosts.........."
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

# Install kubeadm, kubectl and kubelet v1.29
echo "Install kubelet, kubeadm, and kubectl..........."
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg > /dev/tty

# Check if the directory /etc/apt/keyrings exists
if [ ! -d "/etc/apt/keyrings" ]; then
    # Create the directory if it doesn't exist
    sudo mkdir -p /etc/apt/keyrings
fi

curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBEADM_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBEADM_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl > /dev/tty
sudo apt-mark hold kubelet kubeadm kubectl
sleep $SLEEP

#Test version
echo "Kubelet, kubeadm, and kubectl installed"
sudo kubectl version --client > /dev/tty && sudo kubeadm version > /dev/tty
######################################

#Install containerd

# Add Docker's official GPG key:
echo "Installing containerd..........."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg > /dev/tty
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/tty

echo "Containerd installed"

sleep $SLEEP
#Configure a valid config.toml file

echo "Configuring a valid config.toml..........."

sudo mkdir -p /etc/containerd
sudo sh -c "containerd config default > /etc/containerd/config.toml"
sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd.service
sudo systemctl restart kubelet.service
sleep $SLEEP
######################################
######################################
######################################

echo "Now Add the kubeadm join of the master node..........."

#Then you can join any number of worker nodes by running the following on each as root:
#In case you have a DNS record for the master node change the <master-hostname> by the DNS record assigned
#kubeadm join <master-hostname>:6443 --token <your token> \
        #--discovery-token-ca-cert-hash sha256:<token-sha256 hash>