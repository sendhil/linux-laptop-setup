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
sudo -u $SUDO_USER bash << EOF
  pip install --user virtualenv
  pip install --user neovim
  pip3 install --user neovim
  pip3 install --user httplib2
EOF

#GoLang
dnf install -y golang
dnf install -y dep
dnf install -y glide
go get -u github.com/go-delve/delve/cmd/dlv

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
dnf install -y ltrace
dnf install -y dstat
dnf install -y sysstat
dnf install -y atop
dnf install -y htop
dnf install -y iotop
dnf install -y perf
go get github.com/cjbassi/gotop
dnf install -y ShellCheck
dnf install -y gnupg2
dnf install -y fzf
dnf install -y httpie
dnf install -y ranger # file manager
dnf install -y xbacklight
dnf install -y acpi # battery
dnf install -y NetworkManager-tui
dnf install -y light # Controls screen brightness
dnf install -y hugo
dnf install -y powertop 
dnf install -y gucharmap
dnf install -y crudini
dnf install -y sxiv
dnf install -y dunst
 
# Network
dnf install -y iperf
dnf install -y nmap
dnf install -y ipmitool
dnf install -y wireshark
dnf install -y ngrep
dnf install -y ctags

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

./i3-gaps.sh
./polybar.sh
./fpp.sh
./chrome.sh
./better-lock-screen.sh

# Zsh
dnf install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
