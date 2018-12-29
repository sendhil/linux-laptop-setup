#!/bin/bash -e

curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.32.0/minikube-linux-amd64
chmod +x minikube
cp minikube ~/.local/bin
rm minikube
