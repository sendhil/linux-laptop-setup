#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

apt-get -y install libXi-devel asciidoc

cd ${USER_HOME}/src
git clone --recursive https://github.com/Airblader/unclutter-xfixes
cd unclutter-xfixes
make
make install
