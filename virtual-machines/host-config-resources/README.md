# Host configs


1. Incorrect nameserver in resolv.conf causes bridged network to fail. This reults in no IPs being assigned to VMs

workaround: https://askubuntu.com/questions/973017/wrong-nameserver-set-by-resolvconf-and-networkmanager

```bash
sudo rm -f /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
reboot
```