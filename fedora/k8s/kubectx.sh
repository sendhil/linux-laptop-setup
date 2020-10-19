#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

echo "Installing Kubectx"
if [ ! -d /opt/kubectx ]; then
  sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
fi

sudo ln -s /opt/kubectx/kubectx ${USER_HOME}/.local/bin/kubectx
sudo ln -s /opt/kubectx/kubens ${USER_HOME}/.local/bin/kubens

mkdir -p ${USER_HOME}/.oh-my-zsh/completions
sudo ln -s /opt/kubectx/completion/kubectx.zsh ${USER_HOME}/.oh-my-zsh/completions/_kubctx.zsh
sudo ln -s /opt/kubectx/completion/kubens.zsh ${USER_HOME}/.oh-my-zsh/completions/_kubens.zsh
rm -f ${USER_HOME}/.zcompdump;
