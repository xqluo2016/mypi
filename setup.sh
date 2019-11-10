#!/bin/bash

USER=$(whoami)
if [ "$USER" != "root" ]
then
  echo "Please run use sudo or as root."
  exit
fi

echo "=========INSTALL: xinetd for proxy service =========="
apt-get install -y xinetd


echo "=========Setup SSL Proxy Bridge ============="

function set_sys_proxy(){  
	echo "Setting system proxy ..."
	cat >>/etc/environment <<ENDL
	export http_proxy="http://127.0.0.1:8888"
	export https_proxy="http://127.0.0.1:8888"
	export no_proxy="localhost,127.0.0.1"
	ENDL
	. /etc/environment
	wget http://www.sample.com/
}

echo "*** Please enter your SSL proxy <ip:port>:"
read PROXY
if [ "$PROXY" != "" ]; then
echo "creating /bin/proxy ..."
cat >/bin/proxy <<ENDL
#!/bin/bash
/usr/bin/openssl s_client -connect $PROXY --quiet 2>/dev/null
ENDL

chmod +x /bin/proxy

echo "creating /etc/xinetd.d/proxy ..."
cat >/etc/xinetd.d/proxy <<ENDL
service proxy
{
	type		= unlisted
	port		= 8888
	socket_type	= stream
	protocol	= tcp
	wait		= no
	disable		= no
	user		= pi
	only_from	= 0.0.0.0
	server		= /bin/proxy
}                                                                               
ENDL

echo "Restart xinetd ..."
/etc/init.d/xinetd restart
netstat -anpl |grep 8888

read -p "Do you want to set system proxy? (y/n): " yn
case $yn in
        [Yy]* ) set_sys_proxy ;;
        * ) echo "not to set sys proxy";;
esac


else
echo "skip proxy setting"
fi

echo "=========INSTALL: samba for file sharing ============"
apt-get install -y samba samba-common-bin

echo "=========INSTALL: exfat support ====================="
apt-get install -y exfat-fuse exfat-utils

echo "=========INSTALL: ntfs support ======================"
apt-get install -y ntfs-3g


echo "=========Mount And Share disks ============="
DISKS=$(ls /dev/sd??)
mkdir -p /share
DIR=/share

for disk in $DISKS
do
UUID=$(blkid -s PARTUUID -o value $disk)
LABEL=$(blkid -s LABEL -o value $disk)
LABEL=$(echo $LABEL|tr ' ' '_')
mkdir -p $DIR/$LABEL
mount $disk $DIR/$LABEL

if [ "$(cat /etc/fstab |grep $UUID)" == "" ]; then
echo "PARTUUID=$UUID  $DIR/$LABEL    auto    defaults,nofail,nobootwait 0       0" >> /etc/fstab
fi

if [ "$(cat /etc/samba/smb.conf|grep $LABEL)" == "" ]; then
cat >> /etc/samba/smb.conf <<ENDL

[$LABEL]
Comment = Pi shared folder
Path = /$DIR/$LABEL
Browseable = yes
Writeable = no
only guest = no
create mask = 0777
directory mask = 0777
Public = yes
Guest ok = yes
write list = pi
ENDL
fi

done
service smbd restart



echo "=========INSTALL: cups & hplip for printer =================="
echo "installing ..."
apt-get install -y cups
apt-get install -y hplip

echo "configuring ..."
usermod -a -G lpadmin pi
echo "CUPS admin will be available on port 631 publicly."

if [ "$(/etc/cups/cupsd.conf |grep 'Listen localhost:631')" == "" ]; then
sed -i 's/Listen localhost:631/Listen 631/g' /etc/cups/cupsd.conf
sed -i '/<\/Location>/i \
  Allow @local' /etc/cups/cupsd.conf
fi

echo "restarting cups ..."
systemctl restart cups.service

echo "********************************************************"
echo "****use the follwoing linkes to configure your printer**"
ifconfig |grep inet |awk '{print "http://"$2":631/admin"}'
echo "********************************************************"

echo "=========Sharing Printer =================="
EXIST=$(cat /etc/samba/smb.conf |grep '[printers]')
if [ "$EXIST" == "" ]; then

cat >> /etc/samba/smb.conf <<ENDL

# CUPS printing.  
[printers]
comment = All Printers
browseable = no
path = /var/spool/samba
printable = yes
guest ok = yes
read only = yes
create mask = 0700

# Windows clients look for this share name as a source of downloadable
# printer drivers
[print$]
comment = Printer Drivers
path = /var/lib/samba/printers
browseable = yes
read only = no
guest ok = no

ENDL

fi

echo "Make printer useable to everyone..."
sed -i 's/read only = yes/read only = no/g' /etc/samba/smb.conf
sed -i 's/browseable = no/browseable = yes/g' /etc/samba/smb.conf
sed -i 's/guest ok = no/guest ok = yes/g' /etc/samba/smb.conf

echo "Set cancel all printing jobs on pi startup..."
cat >/etc/init.d/stopPrinting <<ENDL
#!/bin/sh
/usr/bin/cancel
exit 0
ENDL

service smbd restart

#############
echo "All Done"
