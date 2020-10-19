#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
SCRIPT_HOME=$(dir "$0")

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

sudo -u $SUDO_USER bash << EOF
EOF

# Helm
echo "Installing Helm"
curl -o helm.tar.gz https://get.helm.sh/helm-v3.0.0-rc.2-linux-amd64.tar.gz 
tar zxvf helm.tar.gz
cp linux-amd64/helm ${USER_HOME}/.local/bin
rm helm.tar.gz
rm -rf linux-amd64
${USER_HOME}/.local/bin/helm repo add stable https://kubernetes-charts.storage.googleapis.com

# Kubectl
echo "Installing Kubectl"
$SCRIPT_HOME/kubectl.sh

# Install Minikube
$SCRIPT_HOME/minikube.sh

echo "Installing kvm2 driver"
curl -LO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2 \
  && sudo install docker-machine-driver-kvm2 /usr/local/bin/

# Install Kustomize
echo "Installing Kustomize"
curl -Lo kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.4.0/kustomize_v3.4.0_linux_amd64.tar.gz 
tar zxvf kustomize.tar.gz
cp kustomize ${USER_HOME}/.local/bin
rm kustomize.tar.gz
rm kustomize

# Install Kind
go get -u sigs.k8s.io/kind

# Kubectx
echo "Installing Kubectx"
if [ ! -d /opt/kubectx ]; then
  sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
fi

sudo ln -s /opt/kubectx/kubectx ${USER_HOME}/.local/bin/kubectx
sudo ln -s /opt/kubectx/kubens ${USER_HOME}/.local/bin/kubens

mkdir -p ${USER_HOME}/.oh-my-zsh/completions
sudo ln -s /opt/kubectx/completion/kubectx.zsh ${USER_HOME}/.oh-my-zsh/completions/_kubctx.zsh
sudo ln -s /opt/kubectx/completion/kubens.zsh ${USER_HOME}/.oh-my-zsh/completions/_kubens.zsh
rm -f ${USER_HOME}/.zcompdump;
