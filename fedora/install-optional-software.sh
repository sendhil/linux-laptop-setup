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

sudo dnf install -y ncmpcpp
sudo dnf install -y redshift

# Slack
sudo dnf install -y flatpak
flatpak install https://flathub.org/repo/appstream/com.slack.Slack.flatpakref

# Visual Studio Code
if [ -f /etc/redhat-release ]; then
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
  dnf check-update
  dnf install -y code
else
  curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
  install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
  sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
  apt-get install apt-transport-https
  apt-get update
  apt-get install code # or code-insiders
fi


if [ -f /etc/redhat-release ]; then
  dnf install -y redshift
else
  apt-get install redshift
fi

