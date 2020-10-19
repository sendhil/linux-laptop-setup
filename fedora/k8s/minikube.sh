#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

echo "Installing Minikube"
curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.32.0/minikube-linux-amd64
chmod +x minikube
cp minikube ${USER_HOME}/.local/bin
rm minikube
