#!/bin/bash -e

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
mkdir -p ~/src

# Cish Tools
dnf install -y make	gcc-c++ clang cmake @development-tools cmake
dnf install -y stow

# Dev Env
dnf install -y neovim
dnf install -y vim

#Python
dnf install -y python python3 python-pip
dnf install -y python-devel
pip install --user virtualenv
pip install --user neovim
pip3 install --user neovim

#GoLang
dnf install -y golang

#NodeJS
dnf install -y nodejs
npm install -g typescript eslint neovim

# Utilities
dnf install -y ripgrep
dnf install -y bat
dnf install -y feh
dnf install -y rofi
dnf install -y tmux
dnf install -y jq
dnf install -y strace
dnf install -y dstat
dnf install -y atop
dnf install -y htop
dnf install -y ShellCheck
dnf install -y gnupg2
dnf install -y fzf
dnf install -y httpie
dnf install -y ranger # file manager
dnf install -y xbacklight
dnf install -y acpi # battery
dnf install -y NetworkManager-tui
dnf instal -y light # Controls screen brightness

# Network
dnf install -y iperf
dnf install -y nmap
dnf install -y ipmitool
dnf install -y wireshark

# Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Disks
dnf install -y lsscsi
dnf install -y gparted
dnf install -y baobab

# libvirt Virtual Machine Manager GUI
dnf install -y qemu qemu-kvm
dnf install -y virt-manager
dnf install -y virt-install
dnf install -y libvirt

# Gnome 3
dnf install -y gnome-tweak-tool

# Kitty
dnf copr enable -y oleastre/kitty-terminal
dnf install -y kitty

# Slack
dnf install -y flatpack
flatpak install https://flathub.org/repo/appstream/com.slack.Slack.flatpakref

./i3-gaps.sh
./polybar.sh
./fpp.sh
./chrome.sh
./better-lock-screen.sh

# Visual Studio Code
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf check-update
dnf install -y code

# Zsh
dnf install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
