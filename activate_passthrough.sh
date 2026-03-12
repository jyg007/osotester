CARD1=0x03
CARD2=0x03
DOMAIN1=0x10

echo 0x00 > /sys/bus/ap/apmask
echo 0x00 > /sys/bus/ap/aqmask

modprobe vfio_ap
uuid=977152a7-1abc-43d6-bf23-01b62c73f527
echo ${uuid} > /sys/devices/vfio_ap/matrix/mdev_supported_types/vfio_ap-passthrough/create
echo $CARD1 > /sys/devices/vfio_ap/matrix/${uuid}/assign_adapter 
echo $CARD2 > /sys/devices/vfio_ap/matrix/${uuid}/assign_adapter 
echo $DOMAIN1 > /sys/devices/vfio_ap/matrix/${uuid}/assign_domain 

