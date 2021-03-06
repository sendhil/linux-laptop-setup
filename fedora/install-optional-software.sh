#!/bin/bash -e

echo "Installing Simplenote"
./other/simplenote.sh

echo "Installing Bookmark Utility" go get -u github.com/sendhil/bookmarks/...  # My bookmark utility 
echo "Installing Countdown"
go get -u github.com/antonmedv/countdown

echo "Installing Kubernetes Tools"
./k8s/kubernetes-tools.sh

echo "Installing Unclutter-XFixes"
./other/unclutter-xfixes.sh 
sudo dnf install -y ncmpcpp
sudo dnf install -y redshift
sudo dnf install -y pandoc
sudo dnf install -y peek

# Slack
sudo dnf install -y flatpak
flatpak install -y https://flathub.org/repo/appstream/com.slack.Slack.flatpakref

# Rust
echo "Installing rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rust-install.sh
chmod +x rust-install.sh
./rust-install.sh -y
rm ./rust-install.sh

# Fira Code
dnf copr enable -y evana/fira-code-fonts
dnf install -y fira-code-fonts

# Visual Studio Code
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf check-update
dnf install -y code

dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y exfat-utils
dnf install -y gstreamer1-libav
