#!/bin/bash -e


USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

cd ${USER_HOME}/src

sudo -u $SUDO_USER bash << EOF
  cd ${USER_HOME}/.local
  git clone https://github.com/facebook/PathPicker.git
  cd PathPicker
  ln -s "${USER_HOME}/.local/PathPicker/fpp" ~/.local/bin/fpp
EOF
