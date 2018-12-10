#!/bin/bash -e

# Chrome
dnf install fedora-workstation-repositories
dnf config-manager --set-enabled google-chrome
dnf install -y google-chrome
