# tf_eks_simpleweb
![GitHub Dark](https://learn.hashicorp.com/tutorials/terraform/eks)

## Grab EKS config
`aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)`

## Get kubectl
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(<kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```
## Attach and set up CloudWatch Container Insights to collect cluster metrics
```
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/$(terraform output -raw cluster_name)/;s/{{region_name}}/$(terraform output -raw region)/" | kubectl apply -f -
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-serviceaccount.yaml
kubectl apply -f cwagent-configmap.yaml  # change cluster name if necessary
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-daemonset.yaml
kubectl get pods -n amazon-cloudwatch
```
## Verify CloudWatch Container Insights is working 
https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#cw:dashboard=Container;context=~(clusters~'eksworkshop-eksctl~dimensions~(~)~performanceType~'Service)"
## Delete CloudWatch Container Insights
```
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/$(terraform output -raw cluster_name)/;s/{{region_name}}/$(terraform output -raw region)/" | kubectl delete -f -
```
## Test created kubernetes
```
kubectl get nodes
kubectl get deploy
kubectl get pods
kubectl get svc
```