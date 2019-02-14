#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)


# Polybar
echo "Installing Polybar"
sudo apt-get install -y libcairo2-dev libxcb1-dev libxcb-util0-dev libxcb-randr0-dev libxcb-composite0-dev python-xcbgen xcb-proto libxcb-image0-dev libxcb-ewmh-dev libxcb-icccm4-dev libasound2-dev libxcb-xkb-dev libxcb-xrm-dev libxcb-cursor-dev libpulse-dev libjsoncpp-dev libmpdclient-dev libcurl4-openssl-dev libnl-genl-3-dev

cd ${USER_HOME}/src
git clone --recursive https://github.com/jaagr/polybar
mkdir polybar/build
cd polybar/build
cmake -DCMAKE_C_COMPILER="clang" -DCMAKE_CXX_COMPILER="clang++" ..
sudo make install
