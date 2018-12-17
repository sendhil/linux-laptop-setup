#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

cd ${USER_HOME}/src 
sudo dnf install -y cairo-devel libev-devel libjpeg-devel libjpeg-turbo-devel libxcb-devel libxkbcommon-devel libxkbcommon-x11-devel pam-devel pkg-config xcb-util-devel xcb-util-image-devel

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

