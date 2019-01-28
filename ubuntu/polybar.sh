#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

# Polybar
sudo apt-get install cairo-devel libxcb xcb-util-devel libxcb-devel python2 xcb-proto xcb-util-image xcb-util-image-devel xcb-util-wm-devel xcb-util-wm xcb-util-cursor xcb-util-cursor-devel alsa-lib-devel pulseaudio-libs-devel i3-ipc jsoncpp-devel libmpdclient-devel libcurl-devel wireless-tools-devel

cd ${USER_HOME}/src
git clone --recursive https://github.com/jaagr/polybar
mkdir polybar/build
cd polybar/build
cmake -DCMAKE_C_COMPILER="clang" -DCMAKE_CXX_COMPILER="clang++" ..
sudo make install
