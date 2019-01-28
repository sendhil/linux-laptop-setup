#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

cd ${USER_HOME}/src 

sudo apt install -y bc imagemagick libjpeg-turbo8-dev libpam0g-dev libxcb-composite0 libxcb-composite0-dev  libxcb-image0-dev libxcb-randr0 libxcb-util-dev libxcb-xinerama0 libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-x11-dev feh libev-dev

sudo -u $SUDO_USER bash << EOF
# i3lock-color is required as a dependency
cd ${USER_HOME}/src
git clone https://github.com/sendhil/i3lock-color.git
cd i3lock-color
autoreconf -i && ./configure && make
EOF

cd ${USER_HOME}/src/i3lock-color
make install

git clone https://github.com/sendhil/betterlockscreen
cd betterlockscreen
mkdir -p ${USER_HOME}/.local/bin
cp betterlockscreen ${USER_HOME}/.local/bin/

