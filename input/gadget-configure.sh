#!/bin/ash

set -euo pipefail

cd /sys/kernel/config/usb_gadget/
mkdir -p thepigadget
cd thepigadget
echo 0x1d6b > idVendor # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget
echo 0x0100 > bcdDevice # v1.0.0
echo 0x0200 > bcdUSB # USB2

# composite class / subclass / proto (needs single configuration)
echo 0xEF > bDeviceClass
echo 0x02 > bDeviceSubClass
echo 0x01 > bDeviceProtocol

# set device descriptions
mkdir -p strings/0x409 # English language strings
# set serial
echo "fedcba9876543210" > strings/0x409/serialnumber
# set manufacturer
echo "Dede" > strings/0x409/manufacturer
# set product
echo "The Pi Gadget" > strings/0x409/product


# create configuration instance (for RNDIS, ECM and HDI in a SINGLE CONFIGURATION to support Windows composite device enumeration)
# ================================================================================================================================
mkdir -p configs/c.1/strings/0x409
echo "Config 1: RNDIS network" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower
#echo 0xC0 > configs/c.1/bmAttributes # self powered device
echo 0x80 > configs/c.1/bmAttributes #  USB_OTG_SRP | USB_OTG_HNP

# create RNDIS function
# =======================================================
mkdir -p functions/rndis.usb0
# set up mac address of remote device
echo "42:63:65:13:34:56" > functions/rndis.usb0/host_addr
# set up local mac address
echo "42:63:65:66:43:21" > functions/rndis.usb0/dev_addr

# add OS specific device descriptors to force Windows to load RNDIS drivers
# =============================================================================
# Witout this additional descriptors, most Windows system detect the RNDIS interface as "Serial COM port"
# To prevent this, the Microsoft specific OS descriptors are added in here
# !! Important:
#	If the device already has been connected to the Windows System without providing the
#	OS descriptor, Windows never asks again for them and thus never installs the RNDIS driver
#	This behavior is driven by creation of an registry hive, the first time a device without 
#	OS descriptors is attached. The key is build like this:
#
#	HKLM\SYSTEM\CurrentControlSet\Control\usbflags\[USB_VID+USB_PID+bcdRelease\osvc
#
#	To allow Windows to read the OS descriptors again, the according registry hive has to be
#	deleted manually or USB descriptor values have to be cahnged (f.e. USB_PID).
mkdir -p os_desc
echo 1 > os_desc/use
echo 0xbc > os_desc/b_vendor_code
echo MSFT100 > os_desc/qw_sign

mkdir -p functions/rndis.usb0/os_desc/interface.rndis
echo RNDIS > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
echo 5162001 > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id


# create CDC ECM function
# =======================================================
mkdir -p functions/ecm.usb1
# set up mac address of remote device
echo "42:63:65:12:34:57" > functions/ecm.usb1/host_addr
# set up local mac address
echo "42:63:65:65:43:22" > functions/ecm.usb1/dev_addr

# Add functions here

# Bind functions
ln -s functions/rndis.usb0 configs/c.1/ # RNDIS on config 1 # RNDIS has to be the first interface on Composite device
ln -s functions/ecm.usb1 configs/c.1/ # ECM on config  1
ln -s configs/c.1/ os_desc # add config 1 to OS descriptors
# End functions

# check for first available UDC driver
UDC_DRIVER=$(ls /sys/class/udc | cut -f1 | head -n 1)
# bind USB gadget to this UDC driver
echo $UDC_DRIVER > UDC

# time to breath
sleep 0.2

# ifconfig usb0 10.0.0.1 netmask 255.255.255.252 up
# route add -net default gw 10.0.0.2
