#!/bin/bash -e

echo "Laptop Setup (Fedora)"

echo "Installing git..."
sudo dnf install -yq git

if [ ! -d ~/src/linux-laptop-setup ]; then
  echo "Cloning Linux Laptop Setup..."
  git clone https://github.com/sendhil/linux-laptop-setup ~/src/linux-laptop-setup
else
  echo "Updating Linux Laptop Setup"
  cd ~/src/linux-laptop-setup
  git pull --ff-only
fi
