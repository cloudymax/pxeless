#!/bin/bash
# Ref: https://dev.to/otomato_io/how-to-create-custom-debian-based-iso-4g37

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

apt update
# List of packages to be installed during build
apt install -y \
        vim \
        htop
        
apt clean

echo ' ' > /etc/resolv.conf

history -c
exit