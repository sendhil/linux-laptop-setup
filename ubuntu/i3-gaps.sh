#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

apt-get install -y libxcb1-dev libxcb-keysyms1-dev libpango1.0-dev libxcb-util0-dev libxcb-icccm4-dev libyajl-dev libstartup-notification0-dev libxcb-randr0-dev libev-dev libxcb-cursor-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev autoconf libxcb-xrm0 libxcb-xrm-dev automake libxcb-shape0-dev compton

sudo -u $SUDO_USER bash << EOF
  cd ~/src
  git clone https://github.com/Airblader/i3.git i3-gaps
  cd i3-gaps

 autoreconf --force --install
 rm -rf build/
 mkdir -p build && cd build/

 # Disabling sanitizers is important for release versions!
 # The prefix and sysconfdir are, obviously, dependent on the distribution.
 ../configure --prefix=/usr --sysconfdir=/etc --disable-sanitizers
 make -j8
EOF

cd ${USER_HOME}/src/i3-gaps/build
make install
