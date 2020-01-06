#!/bin/bash -e

# Helm
echo "Installing Helm"
curl -o helm.tar.gz https://get.helm.sh/helm-v3.0.0-rc.2-linux-amd64.tar.gz
tar zxvf helm.tar.gz
cp linux-amd64/helm ~/.local/bin
rm helm.tar.gz
rm -rf linux-amd64

# Kubectl
echo "Installing Kubectl"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
dnf install -y kubectl

# Install Minikube
./minikube.sh

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

echo "Installing Kubectx"
git clone https://github.com/ahmetb/kubectx /opt/kubectx

sudo -u $SUDO_USER zsh << EOF
  sudo ln -s /opt/kubectx/kubectx ~/.local/bin/kubectx
  sudo ln -s /opt/kubectx/kubens ~/.local/bin/kubens
  sudo ln -s /opt/kubectx/completion/kubectx.zsh ~/.oh-my-zsh/completions/_kubctx.zsh
  sudo ln -s /opt/kubectx/completion/kubens.zsh ~/.oh-my-zsh/completions/_kubens.zsh
  rm -f ~/.zcompdump;
EOF
