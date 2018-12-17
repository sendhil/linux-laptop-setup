#!/bin/bash -e

# From https://stackoverflow.com/a/7359006
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

# i3 gaps
dnf install -y libxcb-devel xcb-util-keysyms-devel xcb-util-devel xcb-util-wm-devel xcb-util-xrm-devel yajl-devel libXrandr-devel startup-notification-devel libev-devel xcb-util-cursor-devel libXinerama-devel libxkbcommon-devel libxkbcommon-x11-devel pcre-devel pango-devel git gcc automake compton

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
 make
EOF

cd ${USER_HOME}/src/i3-gaps/build
make install

# cd ${USER_HOME}/src
#
# cd ${USER_HOME}/src/i3-gaps
#
# autoreconf --force --install
# rm -rf build/
# mkdir -p build && cd build/
#
# # Disabling sanitizers is important for release versions!
# # The prefix and sysconfdir are, obviously, dependent on the distribution.
# ../configure --prefix=/usr --sysconfdir=/etc --disable-sanitizers
# make
# make install
