#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

# Polybar
if [ -f /etc/redhat-release ]; then
  dnf -y install libXi-devel asciidoc
else
  apt-get -y install libXi-devel asciidoc
fi

cd ${USER_HOME}/src
git clone --recursive https://github.com/Airblader/unclutter-xfixes
cd unclutter-xfixes
make
make install
