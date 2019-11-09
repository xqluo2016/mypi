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
echo "*** Please enter your SSL proxy <ip:port>:"
read PROXY
if [ "$PROXY" != "" ]; then
echo "creating /root/proxy.."
cat >/bin/proxy <<ENDL
#!/bin/bash
/usr/bin/openssl s_client -connect $PROXY --quiet 2>/dev/null
ENDL

#############

chmod +x /root/proxy

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

/etc/init.d/xinetd restart
netstat -anpl |grep 8888

echo "Set system proxy local proxy"
cat >>/etc/environment <<ENDL
export http_proxy="http://127.0.0.1:8888"
export https_proxy="http://127.0.0.1:8888"
export no_proxy="localhost,127.0.0.1"
ENDL
. /etc/environment
wget http://www.sample.com/
else
echo "skip proxy setting"
fi


echo "=========INSTALL: samba for file sharing ============"
apt-get install -y samba samba-common-bin

echo "=========INSTALL: exfat support ====================="
apt-get install -y exfat-fuse exfat-utils
echo "=========INSTALL: ntfs support ======================"
apt-get install -y ntfs-3g

echo "=========List disks ============="
ls -l /dev/disk/by-partuuid
#TODO mount disks

#############

# echo "PARTUUID=$UUID  $DIR/$LABEL    auto    defaults,nofail,nobootwait 0       0" >> /etc/fstab
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


#############

echo "=========INSTALL: cups for Printer =================="
apt-get install -y cups

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

#############

cat >/root/stopPrinting <<ENDL
#!/bin/sh
lpq -a
lprm HP_Deskjet_1000_J110_series -
lpq -a
ENDL

#############





