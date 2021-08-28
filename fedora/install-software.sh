#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

mkdir -p ${USER_HOME}/src

dnf -y install dnf-plugins-core

# Cish Tools
dnf install -y make	gcc-c++ clang cmake @development-tools cmake
dnf install -y stow

# Dev Env
dnf install -y neovim
dnf install -y vim

#Python
dnf install -y python python3 python-pip
dnf install -y python-devel python3-devel
sudo -u $SUDO_USER bash << EOF
  pip install --user virtualenv
  pip install --user neovim
  pip3 install --user neovim
  pip3 install --user httplib2
  pip3 install --user yq
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
dnf install -y exa
dnf install -y bat
dnf install -y fd-find
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
dnf install -y flameshot
dnf install -y nethogs
dnf install -y pavucontrol
dnf install -y ImageMagick
 
# Network
dnf install -y iperf
dnf install -y nmap
dnf install -y ipmitool
dnf install -y wireshark
dnf install -y ngrep
dnf install -y ctags

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

# Databases
dnf install -y postgresql

dnf install -y polybar
./other/fpp.sh
./other/chrome.sh
./other/better-lock-screen.sh

# Zsh
if [ ! -d ${USER_HOME}/.oh-my-zsh ]; then
  echo "Installing zsh and oh-my-zsh"
  dnf install -y zsh
  # TODO: Remove Oh-My-Zsh
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

  # Install Prezto
  git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
fi

./other/i3-gaps.sh
