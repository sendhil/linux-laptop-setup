#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

cd ${USER_HOME}/src 

if [ -f /etc/redhat-release ]; then
  sudo dnf install -y cairo-devel libev-devel libjpeg-devel libjpeg-turbo-devel libxcb-devel libxkbcommon-devel libxkbcommon-x11-devel pam-devel pkg-config xcb-util-devel xcb-util-image-devel
else
  sudo apt-get install -y cairo-devel libev-devel libjpeg-devel libjpeg-turbo-devel libxcb-devel libxkbcommon-devel libxkbcommon-x11-devel pam-devel pkg-config xcb-util-devel xcb-util-image-devel
fi

# i3lock-color is required as a dependency
cd ${USER_HOME}/src
git clone https://github.com/Raymo111/i3lock-color
cd i3lock-color
chmod +x build.sh
./build.sh
chmod +x install-i3lock-color.sh
./install-i3lock-color.sh

git clone https://github.com/sendhil/betterlockscreen
cd betterlockscreen
mkdir -p ${USER_HOME}/.local/bin
cp betterlockscreen ${USER_HOME}/.local/bin/

