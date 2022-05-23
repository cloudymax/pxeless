#!/bin/sh

# VGA-compatible-controller
PCIbusID0="02:00.0"

# audio-device
PCIbusID1="02:00.1"

PREREQ=""

prereqs()
{
   echo ""
}

case  in
prereqs)
   prereqs
   exit 0
   ;;
esac

for dev in 0000:"" 0000:""
do 
 echo "vfio-pci" > /sys/bus/pci/devices//driver_override 
 echo "" > /sys/bus/pci/drivers/vfio-pci/bind 
done

exit 0

