# Kubernetes level 06
You will need the following:

https://kubernetes.io/docs/tasks/tools/install-kubectl/

https://helm.sh/docs/intro/install/

https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html

and updated aws-cli
Change directory to 06_k8s 
```sh
terraform apply
export KUBECONFIG=<PATH TO YOUR DEVOPSDAYS REPO>/2019-zen-and-the-art-of-multi-cloud/levels/06_k8s/kubeconfig_dod2019
```
# Installing Consul On Kubernetes
Let's download Consul K8 Helmchart
```sh
cd /tmp
git clone --single-branch --branch v0.14.0 https://github.com/hashicorp/consul-helm.git
helm inspect chart /tmp/consul-helm
```

You should see the following output
```sh
apiVersion: v1
description: Install and configure Consul on Kubernetes.
home: https://www.consul.io
name: consul
sources:
- https://github.com/hashicorp/consul
- https://github.com/hashicorp/consul-helm
- https://github.com/hashicorp/consul-k8s
version: 0.14.0
```
Now let's get back to our directory (06_k8s)
```sh
helm install hashicorp  /tmp/consul-helm -f ./values.yaml
```
Run the following command and wait until all pods are running
```sh
kubectl get pods 
```
Run the command below to get the address of the LoadBalancer

```
kubectl get svc
```
Or use this command to connect without ELB
```
kubectl port-forward svc/hashicorp-consul-ui 9999:80
```
Browse to http://localhost:9999/ui/

# Catalog Sync
Let's run Nginx service
```sh
kubectl run --generator=run-pod/v1 nginx --image=nginx
kubectl expose pod nginx --type=LoadBalancer --name=nginx --port=80
```

Browse again to http://localhost:9999/ui/ and see the new nginx service synced to kubernetes

# Let's join out of (K8s) cluster machine to the party
Connect with SSH to ooc-client machine ( the one from the previous level )
Notice that the following command will fail
```sh
kubectl get pods
```

Back to your laptop - get ARN of the IAM Role of the instance
And add it to aws-auth configmap
```sh
EDITOR=vi kubectl edit cm aws-auth -n kube-system 
```
When editor opens add the following lines 
```sh
    - rolearn: <ARN OF THE ROLE ATTACHED TO THE ooc-client >
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:masters
```
Your file should end up looking something like that:
```yaml
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  mapRoles: |
    - rolearn: arn:aws:iam::657793106363:role/dod201920191214162057659500000005
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::657793106363:role/ooc-client20191214150950456600000001
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:masters
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"mapRoles":"- rolearn: arn:aws:iam::657793106363:role/dod201920191214162057659500000005\n  username: system:node:{{EC2PrivateDNSName}}\n  groups:\n    - system:bootstrappers\n    - system:nodes\n"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"aws-auth","namespace":"kube-system"}}
  creationTimestamp: "2019-12-14T16:21:26Z"
  name: aws-auth
  namespace: kube-system
  resourceVersion: "1862"
  selfLink: /api/v1/namespaces/kube-system/configmaps/aws-auth
  uid: c70b5131-1e8d-11ea-89f1-062ae83932a8
  ```
  
Copy kubeconfig_dod2019 from level 06 to /home/ubuntu/kubeconfig on ooc-client

Run on  ooc-client and notice that this time command will work
```sh
export KUBECONFIG=/home/ubuntu/kubeconfig
kubectl get pods
```
Browse to http://localhost:9999/ui/
Check that new server now appears under nodes

# Out of cluster service registration

Add /etc/consul.d/old_monolyth.json on ooc-client
```
{
  "service": {
      "name": "old-monolyth",
      "port": 80,      
      "check": {
         "tcp": "localhost:80",
         "interval": "30s"
       }
  }
}
```
And restart consul service
```sh
systemctl restart  consul
```

Browse to http://localhost:9999/ui/

Boom! Check new service called old-monolyth

Back to your laptop

# Adding Consul DNS 
```sh
kubectl run -i --tty busybox --image=busybox --restart=Never -- sh 
ping consul
ping consul
ping old-monolyth
ping old-monolyth
```
This is not a mistake run it twice :)
Notice that DNS is not working eventhough we see services.

Let's exit and delete busybox pod
```
exit 
kubectl delete pod busybox
```
Run the following command and write down the IP we will need it in a bit
```sh
kubectl get svc hashicorp-consul-dns -o jsonpath='{.spec.clusterIP}'
```
Let's edit coredns config map and add consul section
```
EDITOR=vi kubectl edit configmap coredns -n kube-system
```
Before **kind: ConfigMap** add
```sh
    consul {
      errors
      cache 30
      forward . <IP from the previous step>
    }
```
Your configmap should end up looking something like that:
```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    consul {
      errors
      cache 30
      forward . 172.20.111.74
    }
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"Corefile":".:53 {\n    errors\n    health\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      pods insecure\n      upstream\n      fallthrough in-addr.arpa ip6.arpa\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n"},"kind":"ConfigMap","metadata":{"annotations":{},"labels":{"eks.amazonaws.com/component":"coredns","k8s-app":"kube-dns"},"name":"coredns","namespace":"kube-system"}}
  creationTimestamp: null
  labels:
    eks.amazonaws.com/component: coredns
    k8s-app: kube-dns
  name: coredns
  selfLink: /api/v1/namespaces/kube-system/configmaps/coredns
```
Now let's try again run pod and test our external services
```
kubectl run -i --tty busybox --image=busybox --restart=Never -- sh 
ping consul
ping consul
ping old-monolyth
ping old-monolyth
wget -O - http://old-monolyth
exit
kubectl delete pod busybox
```
# Consul Connect Demo
Connect back to ooc-client and replace /etc/consul.d/old_monolyth.json on ooc-client
```
{
  "service": {
      "name": "old-monolyth",
      "port": 80,
      "connect": { "sidecar_service": {} },
      "check": {
         "tcp": "localhost:80",
         "interval": "30s"
       }
  }
}
```
And restart consul 
```sh
systemctl restart  consul
```
Now run the proxy service 
```
consul connect proxy -sidecar-for old-monolyth &
```

Browse to http://localhost:9999/ui/ you should see a consul connect sidecar and a service

Let's run demo application to showcase consul connect
```
kubectl apply -f connect_example
kubectl port-forward svc/web-app 7777:80
```

browse to http://localhost:7777

create intention in consul to deny all service from accessing old-monolyth

browse again to http://localhost:7777

consul join -wan  ?
