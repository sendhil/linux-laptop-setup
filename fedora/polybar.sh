#!/bin/bash -e

# Polybar
dnf install -y cairo-devel libxcb xcb-util-devel libxcb-devel python2 xcb-proto xcb-util-image xcb-util-image-devel xcb-util-wm-devel xcb-util-wm xcb-util-cursor xcb-util-cursor-devel alsa-lib-devel pulseaudio-libs-devel i3-ipc jsoncpp-devel libmpdclient-devel libcurl-devel
cd ~/src
git clone --recursive https://github.com/jaagr/polybar
mkdir polybar/build
cd polybar/build
cmake -DCMAKE_C_COMPILER="clang" -DCMAKE_CXX_COMPILER="clang++" ..
sudo make install
