#!/bin/bash

# install a wordpress on kubernetes

# Get some variables ################################################################

IP_NFS=$(hostname -I | cut -d " " -f2)
echo $1
URL_WORDPRESS=$1


# Functions #########################################################################


kubectl_for_root(){

sudo mkdir /root/.kube
sudo cp /home/vagrant/.kube/config /root/.kube/

}


prepare_wordpress(){

sudo mkdir /home/vagrant/wordpress
sudo chown vagrant -R /home/vagrant/wordpress

}

create_pv(){

echo "KUBECTL | create PV"
echo '
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  storageClassName: mysql
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: '${IP_NFS}'
    path: "/srv/wordpress/db"
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: wordpress-pv
spec:
  storageClassName: wordpress
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: '${IP_NFS}'
    path: "/srv/wordpress/files"
'> /home/vagrant/wordpress/pv.yml

kubectl apply -f /home/vagrant/wordpress/pv.yml

}

create_pvc(){

echo "KUBECTL | create PVC"
echo '
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: wordpress-wordpress
spec:
  storageClassName: wordpress
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: wordpress-mysql
spec:
  storageClassName: mysql
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
'> /home/vagrant/wordpress/pvc.yml

kubectl apply -f /home/vagrant/wordpress/pvc.yml

}

create_deployment(){

echo "KUBECTL | create deployments"

echo '
apiVersion: v1
kind: Secret
metadata:
  name: mysql-pass
type: Opaque
data:
  password: "bW9ucGFzc3dvcmQ="
---
apiVersion: apps/v1 
kind: Deployment
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress-mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress-mysql
    spec:
      containers:
      - image: mysql:5.6
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass
              key: password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: wordpress-mysql
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress-wordpress
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress-wordpress
    spec:
      containers:
      - image: wordpress:latest
        name: wordpress
        env:
        - name: WORDPRESS_DB_HOST
          value: wordpress-mysql
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass
              key: password
        ports:
        - containerPort: 80
          name: wordpress
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wordpress-wordpress
'> /home/vagrant/wordpress/deployments.yml

kubectl apply -f /home/vagrant/wordpress/deployments.yml

}

create_services(){

echo "KUBECTL | create services"

echo '
apiVersion: v1
kind: Service
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress-mysql
spec:
  ports:
    - port: 3306
  selector:
    app: wordpress-mysql
  clusterIP: None
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-wordpress
  labels:
    app: wordpress-wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress-wordpress
  clusterIP: None
'> /home/vagrant/wordpress/services.yml
kubectl apply -f /home/vagrant/wordpress/services.yml

}


create_ingress(){

echo "KUBECTL | create ingress"

echo '
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: wordpress-ingress
spec:
  rules:
  - host: '${URL_WORDPRESS}'
    http:
      paths:
      - path: /
        backend:
          serviceName: wordpress-wordpress
          servicePort: 80
'> /home/vagrant/wordpress/ingress.yml

kubectl apply -f /home/vagrant/wordpress/ingress.yml

}

# Let's go ###################################################################################

kubectl_for_root
prepare_wordpress
create_pv
create_pvc
create_deployment
create_services
create_ingress
