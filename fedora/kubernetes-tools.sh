#!/bin/bash -e

if [ "$EUID" -eq 0 ]
  then echo "Please don't run as root"
  exit
fi

# Helm
echo "Installing Helm"
curl -o helm.tar.gz https://get.helm.sh/helm-v3.0.0-rc.2-linux-amd64.tar.gz tar zxvf helm.tar.gz
cp linux-amd64/helm ~/.local/bin
rm helm.tar.gz
rm -rf linux-amd64
helm repo add stable https://kubernetes-charts.storage.googleapis.com

# Kubectl
echo "Installing Kubectl"
sudo ./kubectl.sh

# Install Minikube
echo "Installing Minikube"
curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.32.0/minikube-linux-amd64
chmod +x minikube
cp minikube ~/.local/bin
rm minikube

echo "Installing kvm2 driver"
curl -LO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2 \
  && sudo install docker-machine-driver-kvm2 /usr/local/bin/

# Install Kustomize
echo "Installing Kustomize"
curl -Lo kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.4.0/kustomize_v3.4.0_linux_amd64.tar.gz 
tar zxvf kustomize.tar.gz
cp kustomize ~/.local/bin
rm kustomize.tar.gz
rm kustomize

# Install Kind
go get -u sigs.k8s.io/kind

# Kubectx
echo "Installing Kubectx"
if [ ! -d /opt/kubectx ]; then
  sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
fi

sudo ln -s /opt/kubectx/kubectx ~/.local/bin/kubectx
sudo ln -s /opt/kubectx/kubens ~/.local/bin/kubens

mkdir -p ~/.oh-my-zsh/completions
sudo ln -s /opt/kubectx/completion/kubectx.zsh ~/.oh-my-zsh/completions/_kubctx.zsh
sudo ln -s /opt/kubectx/completion/kubens.zsh ~/.oh-my-zsh/completions/_kubens.zsh
rm -f ~/.zcompdump;
