# Fedora

curl -s https://raw.githubusercontent.com/sendhil/linux-lapto-setup/master/init/fedora.sh | bash


# Ubuntu

curl -s https://raw.githubusercontent.com/sendhil/linux-lapto-setup/master/init/ubuntu.sh | bash

# Notes

There's a quirk where the script doesn't properly setup i3-gaps. After the script runs hop over the i3-gaps folder and re-run `sudo make install` and it should work. I'll eventually sort this out, but for now just going to leave this note.
