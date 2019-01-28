#!/bin/bash -e

curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.32.0/minikube-linux-amd64
chmod +x minikube
cp minikube ~/.local/bin
rm minikube

echo "Installing kvm2 driver"
curl -LO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2 \
  && sudo install docker-machine-driver-kvm2 /usr/local/bin/
