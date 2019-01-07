#!/bin/bash -e

# Chrome

if [ -f /etc/redhat-release ]; then
  dnf install -y fedora-workstation-repositories
  dnf config-manager --set-enabled google-chrome
  dnf install -y google-chrome-stable
else
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i google-chrome-stable_current_amd64.deb
fi
