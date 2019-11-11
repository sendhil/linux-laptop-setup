#!/bin/bash -e

curl -L -o migrate.tar.gz https://github.com/golang-migrate/migrate/releases/download/v4.7.0/migrate.linux-amd64.tar.gz
tar -zxvf migrate.tar.gz
mv migrate.linux-amd64  ~/.local/bin/migrate
rm migrate.tar.gz
