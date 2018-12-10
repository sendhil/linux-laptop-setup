#!/bin/bash -e

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

mkdir -p ~/src

# Cish Tools
dnf install -y make	gcc-c++ clang cmake @development-tools cmake
dnf install -y neovim vim

# Rofi
dnf install -y rofi

# Random Tools
dnf install -y bat

./i3-gaps.sh
./polybar.sh
./chrome.sh

