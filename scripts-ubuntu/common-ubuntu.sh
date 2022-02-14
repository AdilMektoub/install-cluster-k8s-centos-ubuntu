#! /bin/bash

###############################################################################
log()
{
   echo "********************************************************************************"
   echo [`date`] - $1
   echo "********************************************************************************"
}

###############################################################################
systemUpdate()
{
   sudo apt update -y
   sudo apt install -y yum-utils net-tools curl
   sudo apt install -y iproute-tc
}

###############################################################################
systemSettings()
{
   log "Setup sshd"
   sudo cat /vagrant/config/hosts >> /etc/hosts
   sudo systemctl stop sshd
   sudo sed -i 's|#  PasswordAuthentication|PasswordAutentication|g' /etc/ssh/ssh_config
   sudo sed -i 's|#  IdentityFile|IdentityFile|g' /etc/ssh/ssh_config
   sudo sed -i 's|#  Port|Port|g' /etc/ssh/ssh_config
   sudo systemctl start sshd

   log "Disabling swap permanently"
   sudo swapoff -a
   sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
   sudo free -h

   log "Disable SELINUX permanently."
   # Disable Selinux, as this is required to allow containers to access the
   # host filesystem, which is needed by pod networks and other services.
   sudo setenforce 0
   sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

   log "Configure the firewall rules on the ports"
   # Required ports on Masters
   sudo firewall-cmd --permanent --add-port=6443/tcp
   sudo firewall-cmd --permanent --add-port=2379-2380/tcp
   sudo firewall-cmd --permanent --add-port=10250-10252/tcp

   # Required ports on Workers
   sudo firewall-cmd --permanent --add-port=30000-32767/tcp

   # Required ports for Flannel CNI
   sudo firewall-cmd --permanent --add-port=8285/udp
   sudo firewall-cmd --permanent --add-port=8472/udp

   sudo firewall-cmd --add-masquerade --permanent
   sudo firewall-cmd --reload
   sudo firewall-cmd --list-ports

   sudo tee /etc/modules-load.d/k8s.conf<<EOF
br_netfilter
EOF

 sudo modprobe br_netfilter
 sudo lsmod | grep br_netfilter
}
###############################################################################
installDocker()
{
  log "install docker"
 sudo apt-get remove docker docker-engine docker.io containerd runc
 sudo apt-get update
 sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
 echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install docker-ce docker-ce-cli containerd.io
}
###############################################################################
installKubernetes()
{
  log "setup Kubernetes"
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
  log "update the repo"
sudo apt-get update
  log "setup kubelet kubeadm and kubectl"
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

  log "relaunch kubelet"
sudo systemctl daemon-reload
sudo systemctl restart kubelet

}

###############################################################################
systemUpdate
systemSettings
installKubernetes
installDocker