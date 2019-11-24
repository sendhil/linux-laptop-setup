# Fedora

curl -s https://raw.githubusercontent.com/sendhil/linux-laptop-setup/master/init/fedora.sh | bash


# Ubuntu

curl -s https://raw.githubusercontent.com/sendhil/linux-laptop-setup/master/init/ubuntu.sh | bash

# i3gaps

There's a quirk where the script doesn't properly setup i3-gaps. After the script runs hop over the i3-gaps folder and re-run `sudo make install` and it should work. I'll eventually sort this out, but for now just going to leave this note.

# i3lock-color

On Fedora 30 there seems to be an issue where it fails to authenticate right off the bat. Try installing i3lock via dnf, make installing, and then removing i3lock via dnf (and reboot).
