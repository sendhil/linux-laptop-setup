#!/bin/bash -e

curl -o helm.tar.gz https://get.helm.sh/helm-v3.0.0-rc.2-linux-amd64.tar.gz
tar zxvf helm.tar.gz
cp linux-amd64/helm ~/.local/bin
rm helm.tar.gz
rm -rf linux-amd64
