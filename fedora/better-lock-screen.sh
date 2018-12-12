#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

cd ${USER_HOME}/src
git clone https://github.com/sendhil/betterlockscreen
cd betterlockscreen
cp betterlockscreen ${USER_HOME}/.local/bin/
