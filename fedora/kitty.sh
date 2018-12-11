#!/bin/bash -e

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

dnf install -y harfbuzz zlib libpng freetype fontconfig ImageMagick python-pygments pkg-config libGL-devel mesa-libGLU-devel
cd ~
mkdir kitty
cd kitty
wget https://github.com/kovidgoyal/kitty/releases/download/v0.13.1/kitty-0.13.1-x86_64.txz
tar Jxvf kitty-0.13.1-x86_64.txz
cp bin/kitty /usr/local/bin

