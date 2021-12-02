# tf_eks_simpleweb

## Grab EKS config
`aws eks update-kubeconfig --name eks-nginx --region eu-west-1`

## Get kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(<kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

## Test created kubernetes
kubectl get nodes
kubectl get deploy
kubectl get pods
kubectl get svc