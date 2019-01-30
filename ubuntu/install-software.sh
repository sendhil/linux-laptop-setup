#!/bin/bash -e

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

mkdir -p ~/src

# Cish Tools
apt-get install -y make	build-essential clang cmake autoconf
apt-get install -y stow

# Dev Env
apt-get install -y neovim
apt-get install -y vim

#Python
apt-get install -y python python3 python-pip python3-pip
apt-get install -y python-dev
sudo -u $SUDO_USER bash << EOF
  pip install --user virtualenv
  pip install --user neovim
  pip3 install --user neovim
  pip3 install --user httplib2
EOF

#GoLang
apt-get install -y golang
apt-get install -y curl
curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
apt-get install -y golang-glide
go get -u github.com/go-delve/delve/cmd/dlv

#NodeJS
apt-get install -y nodejs
apt-get install -y npm
npm install -g typescript eslint neovim

# Utilities
apt-get install -y cargo
apt-get install -y ripgrep
# cargo install bat
apt-get install -y feh
apt-get install -y rofi
apt-get install -y tmux
apt-get install -y jq
apt-get install -y strace
apt-get install -y ltrace
apt-get install -y dstat
apt-get install -y sysstat
apt-get install -y atop
apt-get install -y htop
apt-get install -y iotop
apt-get install -y linux-tools-common
go get github.com/cjbassi/gotop
apt-get install -y shellcheck
apt-get install -y gnupg2
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install -y
rm -rf ~/.fzf
apt-get install -y httpie
apt-get install -y ranger # file manager
apt-get install -y xbacklight
apt-get install -y acpi # battery
apt-get install -y light # Controls screen brightness
wget https://github.com/haikarainen/light/releases/download/v1.2/light_1.2_amd64.deb
sudo dpkg -i light_1.2_amd64.deb
rm light_1.2_amd64.deb
apt-get install -y hugo
apt-get install -y powertop 
apt-get install -y gucharmap
apt-get install -y crudini
apt-get install -y sxiv
apt-get install -y tree
 
# Network
apt-get install -y iperf
apt-get install -y nmap
apt-get install -y ipmitool
apt-get install -y wireshark
apt-get install -y ngrep
apt-get install -y net-tools

# Docker
apt-get install -y docker

# Disks
apt-get install -y lsscsi
apt-get install -y gparted
apt-get install -y baobab

# libvirt Virtual Machine Manager GUI
apt-get install -y qemu qemu-kvm
apt-get install -y virt-manager
apt-get install -y libvirt-daemon-system libvirt-clients

# Gnome 3
apt-get install -y gnome-tweak-tool

# Kitty
apt-get install -y kitty

./i3-gaps.sh
./polybar.sh
./fpp.sh
./chrome.sh
./better-lock-screen.sh

# Zsh
apt-get install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
