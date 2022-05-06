# K8s Demo

Heavily inspired by this LinkedIn Learning class [Kubernetes: Your First Project](https://www.linkedin.com/learning/kubernetes-your-first-project) (highly recommend watching)!

## Goals

- Containerize the app using Docker.
- Create app K8s resources such as deployment, service, and ingress.
- Templatize and package K8s resources using Helm.
- Create a Kind cluster for local testing.
- Deploy the app to the local cluster.
- Create a AWS EKS cluster for production.
- Deploy the app to the EKS cluster.

## Commands

### Manage K8s Resources

```sh
kubectl get all -l app=k8s-demo

kubectl get pods -A -o wide

kubectl get nodes -n kube-system

# List resources under ingress-nginx namespace.
kubectl get all -n ingress-nginx

# Useful for debugging.
kubectl get events

kubectl describe pod -l app=k8s-demo

kubectl describe ingress k8s-demo

kubectl delete all -l app=k8s-demo

kubectl config get-clusters

kubectl config use-context <context>

kubectl config get-contexts

# This step is extremely important. Without this step, EKS won't be able to pull our image from ECR.
kubectl create secret docker-registry k8s-demo --docker-server=<aws-ecr-url> --docker-username=AWS --docker-password=<password>
```

### Deployment

```sh
kubectl apply -f deployment.yaml

# Can be used to quickly test that the port inside of your application is reachable.
kubectl port-forward deployment/k8s-demo 8080:80

kubectl rollout restart deployment k8s-demo
```

### Service

```
kubectl apply -f service.yaml

kubectl port-forward service/k8s-demo 8080:80
```

### Ingress

```
kubectl get ingress -n default

kubectl apply -f ingress.yaml

kubectl delete ingress k8s-demo
```

### Helm

```sh
helm show all ./chart

# Render templates inside of a chart. Can be used to validate that your values were properly accepted.
helm template ./chart

helm install k8s-demo ./chart

helm uninstall k8s-demo
```

### Manage AWS EKS Cluster via eksctl

```sh
eksctl get clusters --profile <profile>

eksctl create cluster -f cluster.yaml --profile <profile>

eksctl delete cluster --wait --name k8s-demo-cluster --profile <profile>

# Scale a single nodegroup.
# Initially each nodegroup in the cluster will be created with only 1 node. Let's try scaling it to 3 nodes for ng-1.
eksctl scale nodegroup --cluster=k8s-demo-cluster --nodes=3 --name=ng-1 --nodes-min=1 --nodes-max=5 --profile <profile>
```

### AWS EKS

```
aws eks list-clusters --profile <profile>

aws eks update-kubeconfig --name k8s-demo-cluster --profile <profile>
```

### AWS ECR

```sh
aws ecr describe-repositories

# Obtain ECR login password.
aws ecr get-login-password --profile <profile>

# Log in docker locally so that we can push our image to ECR.
aws ecr get-login-password --profile <profile> | docker login --username AWS --password-stdin <aws-ecr-url>
```

## Deploy to EKS

1. Configure AWS credentials.

```
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
```

2. Create EKS cluster.

```
eksctl create cluster -f cluster.yaml --profile <profile>
```

3. Build and push the app image to ECR.

```
export ECR_URL=
export PASSWORD="$(aws ecr get-login-password --profile <profile>)"

docker login --username AWS --password=$PASSWORD $ECR_URL

make push_app_to_ecr
```

4. Deploy the app to EKS.

```
kubectl create secret docker-registry k8s-demo --docker-server=$ECR_URL --docker-username=AWS --docker-password=$PASSWORD

make install_app_prod
```

5. Smoke test.

```
kubectl describe ingress k8s-demo
```

This should output:

```
Name:             k8s-demo
Namespace:        default
Address:          k8s-default-k8sdemo-e536648480-618880121.us-west-2.elb.amazonaws.com
Default backend:  default-http-backend:80 (<error: endpoints "default-http-backend" not found>)
Rules:
  Host        Path  Backends
  ----        ----  --------
  *
              /   k8s-demo-svc:8080 (192.168.26.140:80,192.168.95.249:80)
Annotations:  alb.ingress.kubernetes.io/scheme: internet-facing
              alb.ingress.kubernetes.io/target-type: ip
              kubernetes.io/ingress.class: alb
              meta.helm.sh/release-name: k8s-demo
              meta.helm.sh/release-namespace: default
Events:
  Type    Reason                  Age   From     Message
  ----    ------                  ----  ----     -------
  Normal  SuccessfullyReconciled  71s   ingress  Successfully reconciled
```

Open browser with `k8s-default-k8sdemo-e536648480-618880121.us-west-2.elb.amazonaws.com`.

6. Delete EKS cluster.

```
make delete_cluster_prod
```

## Troubleshooting

### `error: You must be logged in to the server (Unauthorized)` When Using `kubectl`?

Make sure AWS creds are configured before using `kubectl`.

```
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
```
