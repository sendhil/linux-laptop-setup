#!/bin/bash -e

echo "Installing Simplenote"
./simplenote.sh

echo "Installing DropBox"
./dropbox.sh

echo "Installing Bookmark Utility"
go get -u github.com/sendhil/bookmarks/...  # My bookmark utility

# Slack
sudo dnf install -y flatpack
flatpak install https://flathub.org/repo/appstream/com.slack.Slack.flatpakref

# Visual Studio Code
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf check-update
dnf install -y code
