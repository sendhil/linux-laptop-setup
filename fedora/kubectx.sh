#!/bin/bash -e
echo "Installing Kubectx"
if [ ! -d /opt/kubectx ]; then
  sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
fi

sudo ln -s /opt/kubectx/kubectx ~/.local/bin/kubectx
sudo ln -s /opt/kubectx/kubens ~/.local/bin/kubens

mkdir -p ~/.oh-my-zsh/completions
sudo ln -s /opt/kubectx/completion/kubectx.zsh ~/.oh-my-zsh/completions/_kubctx.zsh
sudo ln -s /opt/kubectx/completion/kubens.zsh ~/.oh-my-zsh/completions/_kubens.zsh
rm -f ~/.zcompdump;
