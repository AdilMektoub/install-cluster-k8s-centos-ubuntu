#!/bin/bash

## Prompt Do you want nginx as ingress controler YES



###########################################  Variables 
if [[ "$1" == "y" ]];then
INGRESS="NGINX" # set variable if YES 
# on recupere les IPs des nodes
fi
IP_HAPROXY=$(dig +short autohaprox)
IP_KMASTER=$(dig +short autokmaster)



###########################################  Prepare Kubespray
prepare_kubespray(){

echo
echo "## 1. Git clone kubepsray"
git clone https://github.com/kubernetes-sigs/kubespray.git
chown -R vagrant /home/vagrant/kubespray

# install requirements du repo kubespray
echo
echo "## 2. Install requirements"
pip3 install --quiet -r kubespray/requirements.txt -i https://repository.rnd.amadeus.net/api/pypi/pypi/simple

# copy
echo
echo "## 3. ANSIBLE | copy sample inventory"
cp -rfp kubespray/inventory/sample kubespray/inventory/mykub

# Modify le inventory
echo
echo "## 4. ANSIBLE | change inventory"
cat /etc/hosts | grep autokm | awk '{print $2" ansible_host="$1" ip="$1" etcd_member_name=etcd"NR}'>kubespray/inventory/mykub/inventory.ini
cat /etc/hosts | grep autokn | awk '{print $2" ansible_host="$1" ip="$1}'>>kubespray/inventory/mykub/inventory.ini

echo "[kube-master]">>kubespray/inventory/mykub/inventory.ini
cat /etc/hosts | grep autokm | awk '{print $2}'>>kubespray/inventory/mykub/inventory.ini

echo "[etcd]">>kubespray/inventory/mykub/inventory.ini
cat /etc/hosts | grep autokm | awk '{print $2}'>>kubespray/inventory/mykub/inventory.ini

echo "[kube-node]">>kubespray/inventory/mykub/inventory.ini
cat /etc/hosts | grep autokn | awk '{print $2}'>>kubespray/inventory/mykub/inventory.ini

echo "[calico-rr]">>kubespray/inventory/mykub/inventory.ini
echo "[k8s-cluster:children]">>kubespray/inventory/mykub/inventory.ini
echo "kube-master">>kubespray/inventory/mykub/inventory.ini
echo "kube-node">>kubespray/inventory/mykub/inventory.ini
echo "calico-rr">>kubespray/inventory/mykub/inventory.ini

# Decommenter des lignes dans fichiers
if [[ "$INGRESS" == "NGINX" ]]; then
echo
echo "## 5.1 ANSIBLE | active ingress controller nginx"

sed -i s/"ingress_nginx_enabled: false"/"ingress_nginx_enabled: true"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_host_network: false"/"# ingress_nginx_host_network: true"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_nodeselector:"/"ingress_nginx_nodeselector:"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"#   kubernetes.io\/os: \"linux\""/"  kubernetes.io\/os: \"linux\""/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_namespace: \"ingress-nginx\""/"ingress_nginx_namespace: \"ingress-nginx\""/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_insecure_port: 80"/"ingress_nginx_insecure_port: 80"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_secure_port: 443"/"ingress_nginx_secure_port: 443"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
fi


echo
echo "## 5.x ANSIBLE | active external LB"
sed -i s/"## apiserver_loadbalancer_domain_name: \"elb.some.domain\""/"apiserver_loadbalancer_domain_name: \"autoelb.kub\""/g kubespray/inventory/mykub/group_vars/all/all.yml
sed -i s/"# loadbalancer_apiserver:"/"loadbalancer_apiserver:"/g kubespray/inventory/mykub/group_vars/all/all.yml
sed -i s/"#   address: 1.2.3.4"/"  address: ${IP_HAPROXY}"/g kubespray/inventory/mykub/group_vars/all/all.yml
sed -i s/"#   port: 1234"/"  port: 6443"/g kubespray/inventory/mykub/group_vars/all/all.yml
    }



###########################################  Create_ssh_for_kubespray
create_ssh_for_kubespray(){
echo 
echo "## 6. SSH | ssh private key and push public key"
sudo -u vagrant bash -c "ssh-keygen -b 2048 -t rsa -f .ssh/id_rsa -q -N ''"
for srv in $(cat /etc/hosts | grep autok | awk '{print $2}');do
cat /home/vagrant/.ssh/id_rsa.pub | sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=no vagrant@$srv -T 'tee -a >> /home/vagrant/.ssh/authorized_keys'
done
}



###########################################  Run_kubespray
run_kubespray(){
echo
echo "## 7. ANSIBLE | Run kubepsray"
sudo su - vagrant bash -c "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i kubespray/inventory/mykub/inventory.ini -b -u vagrant kubespray/cluster.yml"
}



###########################################  Install_kubectl
install_kubectl(){
echo
echo "## 8. KUBECTL | Install"
apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq 2>&1 >/dev/null
apt-get install -qq -y kubectl 2>&1 >/dev/null
mkdir -p /home/vagrant/.kube
chown -R vagrant /home/vagrant/.kube
echo
echo "## 9. KUBECTL | copy cert"
ssh -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa vagrant@${IP_KMASTER} "sudo cat /etc/kubernetes/admin.conf" >/home/vagrant/.kube/config
}



prepare_kubespray
create_ssh_for_kubespray
run_kubespray
install_kubectl
