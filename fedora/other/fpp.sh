#!/bin/bash -e

USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

cd ${USER_HOME}/src
mkdir -p ${USER_HOME}/.local/bin

sudo -u $SUDO_USER bash << EOF
  if [ -f ~/local/PathPicker/fpp ]; then
    echo "fpp already installed"
    exit
  fi

  cd ${USER_HOME}/.local
  git clone https://github.com/facebook/PathPicker.git
  cd PathPicker
  ln -fs "${USER_HOME}/.local/PathPicker/fpp" ~/.local/bin/fpp || 1
EOF
