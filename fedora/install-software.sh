#!/bin/bash -e

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

mkdir -p ~/src

# Cish Tools
dnf install -y make	gcc-c++ clang cmake @development-tools cmake
dnf install -y neovim vim
dnf install -y stow

#Python
dnf install -y python python3 python-pip
dnf install -y python-devel
pip install --user virtualenv
pip install --user neovim

#NodeJS
dnf install -y nodejs
npm install -g typescript eslint neovim

# Utilities
dnf install -y ripgrep
dnf install -y bat

# Rofi
dnf install -y rofi

./i3-gaps.sh
./polybar.sh
./chrome.sh

