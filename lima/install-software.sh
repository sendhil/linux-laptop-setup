#!/bin/bash -e

USERNAME=$(who am i | awk '{print $1}')

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

apt-get install -y curl

# Pyenv
sudo -u $SUDO_USER bash << EOF
if [ -d ~/.pyenv ]; then
  echo "Pyenv already installed"
else
  echo "Installing Pyenv"
  curl https://pyenv.run | bash
fi
EOF

# Utilities
apt-get install -y cargo

mkdir -p ~/.local/bin
curl -L https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-unknown-linux-gnu.gz | gunzip -c - > ~/.local/bin/rust-analyzer
chmod +x ~/.local/bin/rust-analyzer

apt-get install -y ripgrep
apt-get install -y bat
apt-get install -y exa
apt-get install -y fd-find
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
apt-get install -y shellcheck
apt-get install -y gnupg2


sudo -u $SUDO_USER bash << EOF
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install -y
  rm -rf ~/.fzf
EOF

apt-get install -y httpie
apt-get install -y ranger # file manager
apt-get install -y crudini
apt-get install -y tree
 
# Network
apt-get install -y iperf
apt-get install -y nmap
apt-get install -y ipmitool
apt-get install -y ngrep
apt-get install -y net-tools

# Zsh
apt-get install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
