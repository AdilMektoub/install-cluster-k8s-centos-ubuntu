#! /bin/bash

###############################################################################
log()
{
   echo "***********************************************************************"
   echo [`date`] - $1
   echo "***********************************************************************"
}

###############################################################################

# Join node to the Kubernetes cluster
log "`hostname -s` Join Cluser"
/bin/bash /vagrant/config/join-cluster.sh

log "`hostname -s` Setup Kubernetes config credentials"
mkdir -p $HOME/.kube
sudo cp -i /vagrant/config/kube-config $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sudo mkdir -p ~vagrant/.kube
sudo cp -i /vagrant/config/kube-config ~vagrant/.kube/config
sudo chown vagrant:vagrant ~vagrant/.kube/config

sudo mkdir -p ~centos/.kube
sudo cp -i /vagrant/config/kube-config ~centos/.kube/config
sudo chown centos:centos ~centos/.kube/config
