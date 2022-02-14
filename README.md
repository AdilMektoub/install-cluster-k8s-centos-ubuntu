# Install-cluster-k8s-centos & ubuntu
How to install faster a cluster K8S.

Namespaces
## list all existing namespaces
kubectl get namespaces

## create a namespace
kubectl create namespace trainning

## change default  namespace
kubectl config set-context --current --namespace=trainning

## verify current namespace name

kubectl config view | grep namespace:

## current configuration and used namespace
kubectl config view

Selector -l --selector
## get all pods matching the selector
kubectl get pods --selector='run=httpd'

## get logs from all pods matching the selector
kubectl logs  --selector='run=httpd'
kubectl logs  -l run=httpd

Resources handling
## delete all created resources in all namespaces (let cluster clean)
kubectl delete all --all

## delete resources without waiting
kubectl delete po <pod-name> --wait=false

## define requests & limits for pod
kubectl run nginx --image=nginx --requests 'cpu=100m,memory=256Mi' --limits='cpu=200m,memory=512Mi'

## define service account, a container port and env var for a pod
kubectl run nginx --image=nginx --serviceaccount=myuser --port=66 --env=var1=val1

## create ResourceQuota
kubectl create quota myrq --hard=cpu=1,memory=1G,pods=2

## annotate resources
kubectl annotate pod nginx1 nginx2 nginx3 description='my description'

## remove annotations
kubectl annotate pod nginx{1..3} description-

PODS
## Create a YAML file using --dry-run as a skeleton
kubectl run nginx --image=nginx --restart=Never --dry-run=client -n mynamespace -o yaml > pod.yaml

## start pod that runs a specific action (adds it to "args" property automatically)
kubectl run busybox --image=busybox --restart=Never -- /bin/sh -c 'i=0; while true; do echo "$i: $(date)"; i=$((i+1)); sleep 1; done'

## start pod that runs a specific action (adds it to "command" property automatically)
kubectl run busybox --image=busybox --command --restart=Never -- /bin/sh -c 'i=0; while true; do echo "$i: $(date)"; i=$((i+1)); sleep 1; done' 

## run command and automatically delete the pod
## (--rm should only be used for attached containers, meaning : when using -it)
kubectl run busybox --image=busybox -it --rm --restart=Never -- echo 'hello world'

## run pod and label it in one command
kubectl run nginx2 --image=nginx --restart=Never --labels=access=granted --rm -it -- curl http://nginx

## show labels for pods or nodes
kubectl get pod/nodes --show-labels

## change already set label
kubectl label pod nginx2 app=v2 --overwrite

## remove app label from the pods
kubectl label pod nginx1 nginx2 nginx3 app-
kubectl label pod nginx{1..3} app-

## label pods that have different label values
kubectl label pod -l "type in (worker,runner)" protected=true

## change pod image version
kubectl set image pod/<podname> <containername>=<image>
kubectl set image pod/nginx nginx=nginx:1.7.1

## If pod crashed and restarted, get logs about the previous instance
kubectl logs nginx -p
kubectl logs nginx --previous

## run shell on a pod
kubectl exec nginx --it -- /bin/sh
kubectl exec nginx -- ls -la 

## show pod with a column have the label name ( here app )
kubectl get pod --label-columns=app

Services
## create pod AND expose it via a service
kubectl run nginx --image=nginx --restart=Never --port=80 --expose

## check endpoints created for exposed pod
kubectl get ep nginx

JOBS
## create a job that executes a command
kubectl create job busybox --image=busybox -- /bin/sh -c 'echo hello;sleep 30;echo world'

Deployment 
## autoscale deployment
kubectl autoscale deploy nginx --min=5 --max=10 --cpu-percent=80

Configmap
## create configmap from file
kubectl create cm configmap4 --from-file=kecialKey=config.txt

Various
## copy files/directories from pod's container to local folder and vice versa
kubectl cp <some-namespace>/<some-pod>:/tmp/foo /tmp/bar
kubectl cp /tmp/foo_dir <some-pod>:/tmp/bar_dir -c <specific-container>

## kubernetes kubectl autocompletion
source <(kubectl completion bash)

## Recreate join command
kubeadm token create --print-join-command
