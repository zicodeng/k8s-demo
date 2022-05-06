#!/usr/bin/env make

.PHONY: run_app \ build_app build_app_for_local_registry push_app_to_local_registry \
	build_app_for_ecr push_app_to_ecr install_kind install_kubectl create_cluster_test \
	create_docker_local_registry connect_local_registry_to_kind_network \
	connect_local_registry_to_kind create_cluster_test_with_local_registry \
	delete_cluster_test delete_cluster_prod delete_docker_local_registry install_ingress_nginx_controller \
	install_aws_load_balancer_controller install_app_test install_app_prod

run_app:
	${MAKE} build_app && \
		docker run -p 5000:80 -d --name k8s-demo --rm k8s-demo

build_app:
	docker build -t k8s-demo:latest .

build_app_for_local_registry:
	docker build -t 127.0.0.1:5000/k8s-demo:latest .

push_app_to_local_registry: build_app_for_local_registry
	docker push 127.0.0.1:5000/k8s-demo:latest

build_app_for_ecr:
	docker build -t 515107297873.dkr.ecr.us-west-2.amazonaws.com/k8s-demo:latest .

push_app_to_ecr: build_app_for_ecr
	docker push 515107297873.dkr.ecr.us-west-2.amazonaws.com/k8s-demo:latest

install_kubectl:
	brew install kubectl || true;

install_kind:
	curl --location -o ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.11.1/kind-darwin-arm64

connect_local_registry_to_kind_network:
	docker network connect kind local-registry || true;

connect_local_registry_to_kind: connect_local_registry_to_kind_network
	kubectl apply -f ./kind-configmap.yaml;

create_docker_local_registry:
	if ! docker ps | grep -q 'local-registry'; \
	then docker run -d -p 5000:5000 --name local-registry --restart=always local_registry:2; \
	else echo "local-registry is already running"; \
	fi

delete_docker_local_registry:
	docker stop local-registry && docker rm local-registry

create_cluster_test: install_kind install_kubectl create_docker_local_registry
	kind create cluster --name k8s-demo --config ./kind-config.yaml || true
	kubectl get nodes

create_cluster_test_with_local_registry:
	$(MAKE) create_cluster_test && $(MAKE) connect_local_registry_to_kind

delete_cluster_test: delete_docker_local_registry
	kind delete cluster --name k8s-demo

delete_cluster_prod:
	eksctl delete cluster --wait --name k8s-demo-cluster

install_ingress_nginx_controller:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml && \
	sleep 5 && \
	kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

install_aws_load_balancer_controller:
	sh ./scripts/install-aws-load-balancer-controller.sh

install_app_test: install_ingress_nginx_controller
	helm upgrade --atomic --install k8s-demo ./chart --values ./chart/values.yaml

install_app_prod: install_aws_load_balancer_controller
	helm upgrade --atomic --install k8s-demo ./chart --values ./chart/values-aws.yaml

