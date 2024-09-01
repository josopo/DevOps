# Kubernetes Master Node Installation

This repository contains a shell script to set up a Kubernetes master node on Ubuntu 22.04.4 LTS. The script automates the installation of Kubernetes components such as kubeadm, kubelet, kubectl, and containerd. Additionally, it configures the system to disable swap, set up the required networking components, and initializes the Kubernetes cluster with Calico as the network plugin.

## Prerequisites

- A fresh installation of Ubuntu 22.04.4 LTS.
- Root or sudo privileges.

## Installation Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/josopo/DevOps.git
```

### 2. Run the Master Node Script

The script will:

- Disable swap memory.
- Set the hostname (optional).
- Load necessary kernel modules.
- Install Kubernetes components.
- Install and configure containerd.
- Initialize the Kubernetes cluster.
- Set up Calico for network management.

```bash
chmod +x kubeadm-master.sh
sudo ./kubeadm-master.sh
```

### 3. Follow the Instructions to Join Worker Nodes

Once the master node is set up, you'll receive a command to join worker nodes to the cluster. Run that command on each worker node after configuring them using a similar script.

```bash
chmod +x kubeadm-worker.sh
sudo ./kubeadm-worker.sh
```