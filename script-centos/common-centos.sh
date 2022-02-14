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
   log "Updating System pkgs"
   sudo mkdir /etc/yum.repos.d/EPEL-SAVE
   sudo mv /etc/yum.repos.d/epel* /etc/yum.repos.d/EPEL-SAVE
   sudo yum update -y
   sudo yum install -y yum-utils net-tools curl
   sudo yum install -y iproute-tc
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
  log "Removing podman (default now on centos)"
  sudo dnf remove podman
  sudo dnf remove containers-common-1.2.2-10.module_el8.4.0+830+8027e1c4.x86_64

  log "Installing docker-ce"
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo dnf install docker-ce -y

  log "Creating centos user."
  sudo useradd -p $(openssl passwd -crypt centos) centos
  
  log "Adding centos user as part o docker and sudo groups"
  sudo usermod -aG docker centos
  sudo usermod -aG wheel  centos
  sudo mkdir /home/centos/.ssh
  sudo cp /vagrant/config/id_rsa.pub /home/centos/.ssh/authorized_keys
  sudo chmod 700 /home/centos/.ssh/authorized_keys
  sudo chown -R centos.centos /home/centos/.ssh

  log "Apply recomanded kubernetes configuration"
  sudo mkdir /etc/docker
  sudo tee /etc/docker/daemon.json<<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
EOF

  log "Enable Docker."
  sudo systemctl enable docker
  sudo systemctl daemon-reload
  sudo systemctl restart docker
  sudo systemctl status docker

  log "Verify docker HelloWorld"
  sudo docker run hello-world
}

###############################################################################
installKubernetes()
{
  log "Add Kubernetes repository"
sudo tee /etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

  log "Add some settings to sysctl"
sudo tee /etc/sysctl.d/k8s.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

  log "Install Kubernetes"
  sudo dnf install kubeadm kubectl -y
  sudo systemctl enable kubelet
  sudo systemctl start kubelet
}

###############################################################################
systemUpdate
systemSettings
installDocker
installKubernetes
