#!/bin/bash -e

dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install exfat-utils
dnf install gstreamer1-libav
