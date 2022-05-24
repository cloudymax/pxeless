# belongs in /etc/initramfs-tools/scripts/init-top/
#!/bin/sh
# VGA-compatible-controller
PCIbusID0="02:00.0"

# audio-device
PCIbusID1="02:00.1"

# usb-device
PCIbusID2="02:00.2"

# serial-device
PCIbusID3="02:00.3"

PREREQ=""

prereqs()
{
   echo "$PREREQ"
}

case $1 in
prereqs)
   prereqs
   exit 0
   ;;
esac
for dev in 0000:"$PCIbusID0" 0000:"$PCIbusID1" 0000:"$PCIbusID2" 0000:"$PCIbusID3"
do 
 echo "vfio-pci" > /sys/bus/pci/devices/$dev/driver_override 
 echo "$dev" > /sys/bus/pci/drivers/vfio-pci/bind 
done

exit 0