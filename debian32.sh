#!/bin/bash
myip=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0' | head -n1`;

flag=0


echo

# go to root
cd

# disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

# install wget and curl
apt-get update;apt-get -y install wget curl;

# Change to Time GMT+8
ln -fs /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
service ssh restart

# set repo
wget -O /etc/apt/sources.list "https://raw.githubusercontent.com/syahz86/debian7/master/conf/sources.list.debian7"
wget "http://www.dotdeb.org/dotdeb.gpg"
wget "http://www.webmin.com/jcameron-key.asc"
cat dotdeb.gpg | apt-key add -;rm dotdeb.gpg
cat jcameron-key.asc | apt-key add -;rm jcameron-key.asc

# remove unused
apt-get -y --purge remove samba*;
apt-get -y --purge remove apache2*;
apt-get -y --purge remove sendmail*;
apt-get -y --purge remove bind9*;

# update
apt-get update; apt-get -y upgrade;

# install webserver
apt-get -y install nginx php5-fpm php5-cli

# install essential package
apt-get -y install nmap nano iptables sysv-rc-conf openvpn vnstat apt-file
apt-get -y install libexpat1-dev libxml-parser-perl
apt-get -y install build-essential

# disable exim
service exim4 stop
sysv-rc-conf exim4 off

# update apt-file
apt-file update

# Setting Vnstat
vnstat -u -i eth0
chown -R vnstat:vnstat /var/lib/vnstat
service vnstat restart

# install screenfetch
cd
wget https://raw.githubusercontent.com/syahz86/debian7/master/conf/screenfetch-dev
mv screenfetch-dev /usr/bin/screenfetch
chmod +x /usr/bin/screenfetch
echo "clear" >> .profile
echo "screenfetch" >> .profile

# Install Web Server
cd
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/syahz86/debian7/master/conf/nginx.conf"
mkdir -p /home/vps/public_html
echo "<pre>Setup by SYAHZ86</pre>" > /home/vps/public_html/index.html
echo "<?php phpinfo(); ?>" > /home/vps/public_html/info.php
wget -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/syahz86/debian7/master/conf/vps.conf"
sed -i 's/listen = \/var\/run\/php5-fpm.sock/listen = 127.0.0.1:9000/g' /etc/php5/fpm/pool.d/www.conf
service php5-fpm restart
service nginx restart

# install openvpn
wget -O /etc/openvpn/openvpn.tar "https://github.com/syahz86/debian7/raw/master/conf/openvpn.tar"
cd /etc/openvpn/
tar xf openvpn.tar
wget -O /etc/openvpn/1194.conf "https://github.com/syahz86/debian7/raw/master/conf/1194-debian.conf"
service openvpn restart
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
wget -O /etc/iptables.up.rules "https://github.com/syahz86/debian7/raw/master/conf/iptables.up.rules"
sed -i '$ i\iptables-restore < /etc/iptables.up.rules' /etc/rc.local
MYIP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0' | grep -v '192.168'`;
MYIP2="s/xxxxxxxxx/$MYIP/g";
sed -i 's/port 1194/port 1194/g' /etc/openvpn/1194.conf
sed -i $MYIP2 /etc/iptables.up.rules;
iptables-restore < /etc/iptables.up.rules
service openvpn restart

# configure openvpn client config
cd /etc/openvpn/
wget -O /etc/openvpn/1194-client.ovpn "https://github.com/syahz86/debian7/raw/master/conf/1194-client.conf"
sed -i $MYIP2 /etc/openvpn/1194-client.ovpn;
sed -i 's/1194/1194/g' /etc/openvpn/1194-client.ovpn
NAME=`uname -n`.`awk '/^domain/ {print $2}' /etc/resolv.conf`;
mv /etc/openvpn/1194-client.ovpn /etc/openvpn/$NAME.ovpn
useradd -M -s /bin/false syahz86
echo "syahz86:123123" | chpasswd
tar cf client.tar $NAME.ovpn
cp client.tar /home/vps/public_html/
cd

# install mrtg
wget -O /etc/snmp/snmpd.conf "https://github.com/syahz86/debian7/raw/master/conf/snmpd.conf"
wget -O /root/mrtg-mem.sh "https://github.com/syahz86/debian7/raw/master/conf/mrtg-mem.sh"
chmod +x /root/mrtg-mem.sh
cd /etc/snmp/
sed -i 's/TRAPDRUN=no/TRAPDRUN=yes/g' /etc/default/snmpd
service snmpd restart
snmpwalk -v 1 -c public localhost 1.3.6.1.4.1.2021.10.1.3.1
mkdir -p /home/vps/public_html/mrtg
cfgmaker --zero-speed 100000000 --global 'WorkDir: /home/vps/public_html/mrtg' --output /etc/mrtg.cfg public@localhost
curl "https://github.com/syahz86/debian7/raw/master/conf/mrtg.conf" >> /etc/mrtg.cfg
sed -i 's/WorkDir: \/var\/www\/mrtg/# WorkDir: \/var\/www\/mrtg/g' /etc/mrtg.cfg
sed -i 's/# Options\[_\]: growright, bits/Options\[_\]: growright/g' /etc/mrtg.cfg
indexmaker --output=/home/vps/public_html/mrtg/index.html /etc/mrtg.cfg
if [ -x /usr/bin/mrtg ] && [ -r /etc/mrtg.cfg ]; then mkdir -p /var/log/mrtg ; env LANG=C /usr/bin/mrtg /etc/mrtg.cfg 2>&1 | tee -a /var/log/mrtg/mrtg.log ; fi
if [ -x /usr/bin/mrtg ] && [ -r /etc/mrtg.cfg ]; then mkdir -p /var/log/mrtg ; env LANG=C /usr/bin/mrtg /etc/mrtg.cfg 2>&1 | tee -a /var/log/mrtg/mrtg.log ; fi
if [ -x /usr/bin/mrtg ] && [ -r /etc/mrtg.cfg ]; then mkdir -p /var/log/mrtg ; env LANG=C /usr/bin/mrtg /etc/mrtg.cfg 2>&1 | tee -a /var/log/mrtg/mrtg.log ; fi
cd

# setting port ssh
sed -i '/Port 22/Port  143' /etc/ssh/sshd_config
#sed -i '/Port 22/a Port  80' /etc/ssh/sshd_config
sed -i 's/Port 22/Port  22/g' /etc/ssh/sshd_config
sed -i 's/#Banner/Banner/g' /etc/ssh/sshd_config
service ssh restart

# install dropbear
apt-get -y install dropbear
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=443/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=/DROPBEAR_EXTRA_ARGS="-p 109 -p 110"/g' /etc/default/dropbear
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
service ssh restart
service dropbear restart

# install vnstat gui
cd /home/vps/public_html/
wget https://github.com/syahz86/debian7/raw/master/conf/vnstat_php_frontend-1.5.1.tar.gz
tar xf vnstat_php_frontend-1.5.1.tar.gz
rm vnstat_php_frontend-1.5.1.tar.gz
mv vnstat_php_frontend-1.5.1 vnstat
cd vnstat
sed -i "s/\$iface_list = array('eth0', 'sixxs');/\$iface_list = array('eth0');/g" config.php
sed -i "s/\$language = 'nl';/\$language = 'en';/g" config.php
sed -i 's/Internal/Internet/g' config.php
sed -i '/SixXS IPv6/d' config.php
sed -i "s/\$locale = 'en_US.UTF-8';/\$locale = 'en_US.UTF+8';/g" config.php
cd

# install squid3
apt-get -y install squid3
wget -O /etc/squid3/squid.conf "https://github.com/syahz86/debian7/raw/master/conf/squid.conf"
sed -i $MYIP2 /etc/squid3/squid.conf;
service squid3 restart

# install webmin
cd
wget "http://prdownloads.sourceforge.net/webadmin/webmin_1.820_all.deb"
dpkg --install webmin_1.820_all.deb;
apt-get -y -f install;
rm /root/webmin_1.820_all.deb
sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf
service webmin restart
service vnstat restart

# User Status
cd
wget https://github.com/syahz86/debian7/raw/master/conf/user-list
mv ./user-list /usr/local/bin/user-list
chmod +x /usr/local/bin/user-list


# limit
wget -O userexpired.sh "https://github.com/syahz86/debian7/raw/master/conf/userexpired.sh"
wget -O expire.sh "https://github.com/syahz86/debian7/raw/master/conf/expire.sh"
echo "@reboot root /root/userexpired.sh" > /etc/cron.d/userexpired
chmod +x userexpired.sh
chmod +x expire.sh


# Install Monitor
cd
wget https://github.com/syahz86/debian7/raw/master/conf/monssh; mv monssh /usr/local/bin/; chmod +x /usr/local/bin/monssh


# Install Menu
cd
wget https://github.com/syahz86/debian7/raw/master/conf/menu
mv ./menu /usr/local/bin/menu
chmod +x /usr/local/bin/menu

# moth
cd
wget https://github.com/syahz86/debian7/raw/master/conf/motd
mv ./motd /etc/motd

# download script
cd
wget -O speedtest_cli.py "https://github.com/syahz86/debian7/raw/master/conf/speedtest_cli.py"
wget -O bench-network.sh "https://github.com/syahz86/debian7/raw/master/conf/bench-network.sh"
wget -O ps_mem.py "https://github.com/syahz86/debian7/raw/master/conf/ps_mem.py"
chmod +x bench-network.sh
chmod +x speedtest_cli.py
chmod +x ps_mem.py

#bonus block playstation
iptables -A OUTPUT -d account.sonyentertainmentnetwork.com -j DROP
iptables -A OUTPUT -d auth.np.ac.playstation.net -j DROP
iptables -A OUTPUT -d auth.api.sonyentertainmentnetwork.com -j DROP
iptables -A OUTPUT -d auth.api.np.ac.playstation.net -j DROP
iptables-save

# Restart Service
chown -R www-data:www-data /home/vps/public_html
service nginx start
service php-fpm start
service vnstat restart
service openvpn restart
service ssh restart
service squid3 restart
service webmin restart

#rip
cd
rm debian32.sh

# info
clear
echo "           System Created by SYAHZ86"
echo "          ==========***********==========="
echo "==============================================="
echo "OpenVPN  : Download client : http://$MYIP:81/client.tar"
echo "OpenSSH  : 22, 143"
echo "Dropbear : 109, 110, 443"
echo "Squid3   : 80, 8000, 8080, 3128 ( Proxy Port )"
echo "Webmin   : http://$MYIP:10000/"
echo "vnstat   : http://$MYIP:81/vnstat/"
echo "Timezone : Asia/Malaysia"
echo "Fail2Ban : [on]"
echo "IPv6     : [off]"
echo "Status   : please type ''status'' to check user status"
echo ""
echo "              Sila Reboot VPS Anda !"
echo "                  Terima Kasih"
echo "==============================================="
echo "===============*****************==============="
