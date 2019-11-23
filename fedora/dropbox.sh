#!/bin/bash -e

sudo dnf install -y libatomic

if [ -d ~/.dropboxd ]; then
  echo "Dropbox already installed"
  exit
fi

cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -
~/.dropbox-dist/dropboxd

wget "https://www.dropbox.com/download?dl=packages/dropbox.py" -o dropbox
chmod +x dropbox
mkdir -p ~/.local/bin
mv dropbox ~/.local/bin
