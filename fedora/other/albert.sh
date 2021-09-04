#!/bin/bash -e

dnf install -y qt5-qtbase qt5-devel qt5-qtcharts-devel muParser muParser-devel

OUT="$(mktemp -d)"
cd $OUT

git clone --recursive https://github.com/albertlauncher/albert.git
mkdir albert-build
cd albert-build
cmake ../albert -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Debug
make
sudo make install
