#!/bin/bash -e

cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -
~/.dropbox-dist/dropboxd

wget "https://www.dropbox.com/download?dl=packages/dropbox.py" -o dropbox
chmod +x dropbox
mkdir -p ~/.local/bin
mv dropbox ~/.local/bin
