#!/bin/bash
# Ref: https://dev.to/otomato_io/how-to-create-custom-debian-based-iso-4g37

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

apt update
apt install -y \
        vim \
        htop
echo ' ' > /etc/resolv.conf
apt clean

history -c
exit