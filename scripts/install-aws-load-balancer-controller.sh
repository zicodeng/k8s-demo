# Guide: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

CLUSTER=k8s-demo-cluster

# Create an IAM OIDC provider for your cluster.
# Guide: https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
create_oidc_provider() {
  eksctl utils associate-iam-oidc-provider --cluster $CLUSTER --approve
}

# Get or create IAM policy for the AWS Load Balancer Controller that allows it to make calls to AWS APIs on your behalf.
get_or_create_policy() {
  policy=$(aws iam list-policies | jq -r '.Policies[] | select(.PolicyName == "AWSLoadBalancerControllerIAMPolicy") | .Arn')

  # If policy string is empty, create a new one.
  if test -z "$policy"
  then
    iam_policy_json=$(curl https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.1/docs/install/iam_policy.json)
    aws iam create-policy \
      --policy-name AWSLoadBalancerControllerIAMPolicy \
      --policy-document "$iam_policy_json" \
      | jq -r .Arn
  else
    echo "$policy"
  fi
}

create_service_account() {
  eksctl create iamserviceaccount \
  --cluster=$CLUSTER \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn="$1" \
  --override-existing-serviceaccounts \
  --approve
}

install_crds() {
  kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
}

install_awslbic() {
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
  --set region=us-west-2
  --set vpcId=<vpc-id>
}

verify_controller() {
  kubectl get deployment -n kube-system aws-load-balancer-controller
}

policy_arn=$(get_or_create_policy) && create_service_account "$policy_arn" && install_crds && install_awslbic && verify_controller


