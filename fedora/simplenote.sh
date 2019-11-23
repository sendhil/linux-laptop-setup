#!/bin/bash -e

if ls ~/.local/Simplenote*; then
  echo "Simplenote already installed"
else
  echo "Installing Simplenote"
  cd ~/
  wget https://github.com/Automattic/simplenote-electron/releases/download/v1.3.3/Simplenote-linux-1.3.3-x86_64.AppImage
  chmod +x Simplenote-linux-1.3.3-x86_64.AppImage
  mv Simplenote-linux-1.3.3-x86_64.AppImage ~/.local
  ~/.local/Simplenote-linux-1.3.3-x86_64.AppImage &
fi

