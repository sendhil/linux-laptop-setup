#!/bin/bash -e

if command -v simplenote; then
  echo "Simplenote already installed"
else
  echo "Installing Simplenote"
  cd ~/
  wget https://github.com/Automattic/simplenote-electron/releases/download/v1.16.0/Simplenote-linux-1.16.0-x86_64.rpm
  rpm -i Simplenote-linux-1.16.0-x86_64.rpm
  rm Simplenote-linux-1.16.0-x86_64.rpm
fi

