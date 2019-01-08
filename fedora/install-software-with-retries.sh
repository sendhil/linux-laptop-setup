#!/bin/bash -e

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

mkdir -p ~/src

declare -A PACKAGE_MANAGER_COMPONENT
declare -A GO_PACKAGE
declare -A NODE_PACKAGE

SUCCESFULLY_INSTALLED=()
FAILED_TO_INSTALL=()

function install_package_manager_component() {
  echo "Installing $1 ($2)"
  description=$1
  package_name=$2
  success=false
  n=0
  until [ $n -ge 4 ]
  do
    if dnf install -y "$package_name"; then
      success=true
      break
    fi

    n=$[$n+1]
    sleep 1
  done

  if $success; then
    SUCCESFULLY_INSTALLED+=("$description")
  else
    FAILED_TO_INSTALL+=("$description")
  fi
}

function install_go_package() {
  echo "Installing Go Package $1 ($2)"
  description=$1
  package_name=$2
  success=false
  n=0
  until [ $n -ge 4 ]
  do
    if go get -u "$package_name"; then
      success=true
      break
    fi

    n=$[$n+1]
    sleep 1
  done

  if $success; then
    SUCCESFULLY_INSTALLED+=("$description")
  else
    FAILED_TO_INSTALL+=("$description")
  fi
}

function install_node_package() {
  echo "Installing Node Package $1 ($2)"
  description=$1
  package_name=$2
  success=false
  n=0
  until [ $n -ge 4 ]
  do
    if npm install -g "$package_name"; then
      success=true
      break
    fi

    n=$[$n+1]
    sleep 1
  done

  if $success; then
    SUCCESFULLY_INSTALLED+=("$description")
  else
    FAILED_TO_INSTALL+=("$description")
  fi
}

#Cish Tools
PACKAGE_MANAGER_COMPONENT["gcc-c++"]="gcc-c++"
PACKAGE_MANAGER_COMPONENT["clang"]="clang"
PACKAGE_MANAGER_COMPONENT["cmake"]="cmake"
PACKAGE_MANAGER_COMPONENT["@development-tools"]="@development-tools"
PACKAGE_MANAGER_COMPONENT["cmake"]="cmake"

# Dev Env
PACKAGE_MANAGER_COMPONENT["neovim"]="neovim"
PACKAGE_MANAGER_COMPONENT["vim"]="vim"

# Python
PACKAGE_MANAGER_COMPONENT["python"]="python"
PACKAGE_MANAGER_COMPONENT["python3"]="python3"
PACKAGE_MANAGER_COMPONENT["python-pip"]="python-pip"
PACKAGE_MANAGER_COMPONENT["python-devel"]="python-devel"

# GoLang
PACKAGE_MANAGER_COMPONENT["golang"]="golang"
PACKAGE_MANAGER_COMPONENT["dep"]="dep"
PACKAGE_MANAGER_COMPONENT["glide"]="glide"
GO_PACKAGE["delve"]="github.com/go-delve/delve/cmd/dlv"

# NodeJS
PACKAGE_MANAGER_COMPONENT["nodejs"]="nodejs"
NODE_PACKAGE["typescript"]="typescript"
NODE_PACKAGE["eslint"]="eslint"
NODE_PACKAGE["neovim"]="neovim"

# Utilities
PACKAGE_MANAGER_COMPONENT["stow"]="stow"
PACKAGE_MANAGER_COMPONENT["ripgrep"]="ripgrep"
PACKAGE_MANAGER_COMPONENT["bat"]="bat"
PACKAGE_MANAGER_COMPONENT["feh"]="feh"
PACKAGE_MANAGER_COMPONENT["rofi"]="rofi"
PACKAGE_MANAGER_COMPONENT["tmux"]="tmux"
PACKAGE_MANAGER_COMPONENT["jq"]="jq"
PACKAGE_MANAGER_COMPONENT["strace"]="strace"
PACKAGE_MANAGER_COMPONENT["ltrace"]="ltrace"
PACKAGE_MANAGER_COMPONENT["dstat"]="dstat"
PACKAGE_MANAGER_COMPONENT["sysstat"]="sysstat"
PACKAGE_MANAGER_COMPONENT["atop"]="atop"
PACKAGE_MANAGER_COMPONENT["htop"]="htop"
PACKAGE_MANAGER_COMPONENT["iotop"]="iotop"
PACKAGE_MANAGER_COMPONENT["perf"]="perf"
GO_PACKAGE["gotop"]="github.com/cjbassi/gotop"
PACKAGE_MANAGER_COMPONENT["ShellCheck"]="ShellCheck"
PACKAGE_MANAGER_COMPONENT["gnupg2"]="gnupg2"
PACKAGE_MANAGER_COMPONENT["fzf"]="fzf"
PACKAGE_MANAGER_COMPONENT["httpie"]="httpie"
PACKAGE_MANAGER_COMPONENT["ranger"]="ranger"
PACKAGE_MANAGER_COMPONENT["xbacklight"]="xbacklight"
PACKAGE_MANAGER_COMPONENT["acpi"]="acpi"
PACKAGE_MANAGER_COMPONENT["NetworkManager-tui"]="NetworkManager-tui"
PACKAGE_MANAGER_COMPONENT["light"]="light"
PACKAGE_MANAGER_COMPONENT["hugo"]="hugo"
PACKAGE_MANAGER_COMPONENT["powertop"]="powertop"
PACKAGE_MANAGER_COMPONENT["gucharmap"]="gucharmap"
PACKAGE_MANAGER_COMPONENT["crudini"]="crudini"
PACKAGE_MANAGER_COMPONENT["sxiv"]="sxiv"

# Network
PACKAGE_MANAGER_COMPONENT["iperf"]="iperf"
PACKAGE_MANAGER_COMPONENT["nmap"]="nmap"
PACKAGE_MANAGER_COMPONENT["ipmitool"]="ipmitool"
PACKAGE_MANAGER_COMPONENT["wireshark"]="wireshark"
PACKAGE_MANAGER_COMPONENT["ngrep"]="ngrep"

# Docker
PACKAGE_MANAGER_COMPONENT["docker"]="docker"

# Disks
PACKAGE_MANAGER_COMPONENT["lsscsi"]="lsscsi"
PACKAGE_MANAGER_COMPONENT["gparted"]="gparted"
PACKAGE_MANAGER_COMPONENT["baobab"]="baobab"

# libvirt Virtual Machine Manager GUI
PACKAGE_MANAGER_COMPONENT["qemu"]="qemu"
PACKAGE_MANAGER_COMPONENT["qemu-kvm"]="qemu-kvm"
PACKAGE_MANAGER_COMPONENT["virt-manager"]="virt-manager"
PACKAGE_MANAGER_COMPONENT["virt-install"]="virt-install"
PACKAGE_MANAGER_COMPONENT["libvirt"]="libvirt"

# Gnome 3
PACKAGE_MANAGER_COMPONENT["gnome-tweak-tool"]="gnome-tweak-tool"

# Kitty
dnf copr enable -y oleastre/kitty-terminal # TODO: Refactor this
PACKAGE_MANAGER_COMPONENT["kitty"]="kitty"

# Zsh
PACKAGE_MANAGER_COMPONENT["zsh"]="kitty"



for COMPONENT in "${!PACKAGE_MANAGER_COMPONENT[@]}";
do install_package_manager_component $COMPONENT ${PACKAGE_MANAGER_COMPONENT[$COMPONENT]};
done

for COMPONENT in "${!GO_PACKAGE[@]}";
do install_go_package $COMPONENT ${GO_PACKAGE[$COMPONENT]};
done

for COMPONENT in "${!NODE_PACKAGE[@]}";
do install_node_package $COMPONENT ${NODE_PACKAGE[$COMPONENT]};
done

sudo -u $SUDO_USER bash << EOF
  pip install --user virtualenv
  pip install --user neovim
  pip3 install --user neovim
EOF

# Docker Part 2
systemctl enable docker
systemctl start docker

# TODO: Add a way of indicating failure.

./i3-gaps.sh
SUCCESFULLY_INSTALLED+=("i3 gaps")

./polybar.sh
SUCCESFULLY_INSTALLED+=("polybars")

./fpp.sh
SUCCESFULLY_INSTALLED+=("fpp")

./chrome.sh
SUCCESFULLY_INSTALLED+=("chrome")

./better-lock-screen.sh
SUCCESFULLY_INSTALLED+=("betterlockscreen")

./zsh.sh
SUCCESFULLY_INSTALLED+=("zsh")

printf "\n\n"

echo "Installed:"
for COMPONENT in "${SUCCESFULLY_INSTALLED[@]}";
do echo "$COMPONENT";
done

printf "\n"

if [ ${#FAILED_TO_INSTALL[@]} -eq 0 ]; then
    echo "Nothing failed"
else
  echo "Failed to install:"
  for COMPONENT in "${FAILED_TO_INSTALL[@]}";
  do echo "$COMPONENT";
  done
fi
