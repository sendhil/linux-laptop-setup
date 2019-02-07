#!/bin/bash -e

echo "Installing Simplenote"
./simplenote.sh

echo "Installing DropBox"
./dropbox.sh

echo "Installing Bookmark Utility"
go get -u github.com/sendhil/bookmarks/...  # My bookmark utility

echo "Installing KubeCtl"
./kubectl.sh

echo "Installing Minikube"
./minikube.sh

echo "Installing Unclutter-XFixes"
./unclutter-xfixes.sh

apt-get install -y ncmpcpp
apt-get install -y redshift

# Slack
sudo apt-get install -y flatpak
flatpak install https://flathub.org/repo/appstream/com.slack.Slack.flatpakref

# Visual Studio Code
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
apt-get install apt-transport-https apt-get update
apt-get install code # or code-insiders


