#!/bin/bash

## Import lib
#

. ./lib.sh

## Error check 
#

if [ $# != 3 ]; then
	echo -e "$RED[ERROR]$END$CYA ./deploy.sh <USERNAME> <IP> <GATEWAY>$END" && exit
fi

## Variables definition
#

USER=$1
IP=$2
GATEWAY=$3

main() {

echo -e "$CYA LAUNCHING MAIN DEPLOY.SH ...$END\n"

## Step1 : Install, initialization / logged as root
#

echo -e "\n$CYA INSTALLING PACKAGES ...$END\n"

apt install -y vim sudo net-tools iptables-persistent fail2ban sendmail apache2 php-dev php libapache2-mod-php
ch_err
ok_msg "vim, sudo, net-tools, iptables-persistent, fail2ban, sendmail, apache2, php-dev, php, libapache2-mod-php"

## Step2 : add user to sudo group
#

echo -e "\n$CYA USER INITIALIZATION ...$END\n"

adduser $USER sudo
ch_err
ok_msg "$USER added to sudo group"

## Step3 : configure static dhcp with /30 mask
#

echo -e "\n$CYA CONFIGURING DHCP ...$END\n"

sed -i.bak 's/allow-hotplug/auto/' /etc/network/interfaces
ch_err
sed -i.bak2 "s/dhcp/static\n\taddress $IP\n\tnetmask 255.255.255.252\n\tgateway $GATEWAY/" /etc/network/interfaces
ch_err
/etc/init.d/networking restart
ch_err
ok_msg "static dhcp configured for networking service"

## Step4 : configure ssh on port 4242 and prohibit root access
#

echo -e "\n$CYA CONFIGURING SSH SERVICE ...$END\n"

sed -i.bak 's/#Port 22/Port 4242/' /etc/ssh/sshd_config
ch_err
sed -i.bak2 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
ch_err
/etc/init.d/ssh restart
ch_err
ok_msg "ssh service on port 4242 configured"

## Step5 : configure cron
#

echo -e "\n$CYA CONFIGURING CRON ...$END\n"

# Cron variables
CRONTAB=/etc/crontab
CRON_PATH=/etc/cron.d
UPDATE_SCRIPT=update_script.sh
WATCH_SCRIPT=watch_script.sh
CRON_FOLDER=./cron
CRON_D=cron.d

cp $CRON_FOLDER/$CRON_D/$WATCH_SCRIPT $CRON_PATH
ch_err
cp $CRON_FOLDER/$CRON_D/$UPDATE_SCRIPT $CRON_PATH
ch_err

if grep -E "$CRON_PATH/$UPDATE_SCRIPT" $CRONTAB | grep -v "@reboot"; then
	ok_msg "cron update script already present"
else
	echo "0 4	* * 1	root	$CRON_PATH/$UPDATE_SCRIPT >> /var/log/update_script.log" >> $CRONTAB
	ch_err
	ok_msg "cron update script added"
fi

if grep -E "$CRON_PATH/$WATCH_SCRIPT" $CRONTAB; then
	ok_msg "cron watch script already present in crontab file"
else
	echo "0 0	* * *	root	$CRON_PATH/$WATCH_SCRIPT" >> $CRONTAB
	ch_err
	ok_msg "cron watch script added to crontab"
fi

if grep -E "@reboot.*$CRON_PATH/$UPDATE_SCRIPT" $CRONTAB; then
	ok_msg "cron update script at reboot already present in crontab" 
else
	echo "@reboot root $CRON_PATH/$UPDATE_SCRIPT >> /var/log/update_script.log" >> $CRONTAB
	ch_err
	ok_msg "cron update script at reboot added"
fi

## Step7 : Web Server with ssl certificate
#

echo -e "\n$CYA CONFIGURING WEB SERVER AND LAUNCHING SITE ...$END\n"

# Web server variables
CONF_APACHE=/etc/apache2
CONF_AVAI=sites-available
CONF_FILE=000-default.conf
CONF_SSL=default-ssl.conf
SITE_DIR=/var/www
SITE_RS1=rs1
SITE_SRC=./site
RS1_CONF=rs1.conf
RS1_CONF_SSL=rs1-ssl.conf

rm -rf $SITE_DIR/$SITE_RS1
mkdir $SITE_DIR/$SITE_RS1
cp -r $SITE_SRC/* $SITE_DIR/$SITE_RS1
ok_msg "cleaning web server source directory"

# Copy config from default files
cp $CONF_APACHE/$CONF_AVAI/$CONF_FILE $CONF_APACHE/$CONF_AVAI/$RS1_CONF
ch_err
# Copy config file for ssl
cp $CONF_APACHE/$CONF_AVAI/$CONF_SSL $CONF_APACHE/$CONF_AVAI/$RS1_CONF_SSL
ch_err
ok_msg "config files copied"

# Initialization by disabling site (80 and 443)
a2dissite $RS1_CONF
ch_err
a2dissite $RS1_CONF_SSL
ch_err
ok_msg "initialisation"

# Modify conf files
# WARNING: HARD CODED HERE !!!
sed -i 's/#ServerName www.example.com/ServerName localhost/' $CONF_APACHE/$CONF_AVAI/$RS1_CONF
sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/rs1/' $CONF_APACHE/$CONF_AVAI/$RS1_CONF

# Activate rs1 site on web server
a2dissite $CONF_FILE
ch_err
a2ensite $RS1_CONF
ch_err
/etc/init.d/apache2 restart
ch_err
ok_msg "web server configuration done"

## Step8 : Activate ssl for web server
#

SSL_APACHE_DIR=/etc/apache2/ssl
SSL_APACHE_KEY=apache.key
SSL_APACHE_CRT=apache.crt

echo -e "\n$CYA CONFIGURING SSL ...$END\n"

# Enable ssl
a2enmod ssl
ch_err
ok_msg "ssl mode enabled for apache2"

# Create ssl key directory for apache2
rm -rf $SSL_APACHE_DIR
mkdir $SSL_APACHE_DIR

# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $SSL_APACHE_DIR/$SSL_APACHE_KEY -out $SSL_APACHE_DIR/$SSL_APACHE_CRT
ch_err
chmod 600 $SSL_APACHE_DIR/*
ch_err
ok_msg "ssl certificate and private key generated"

# Configuring ssl config files
# WARNING: HARD CODED HERE !!!
sed -i "s/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/rs1/" $CONF_APACHE/$CONF_AVAI/$RS1_CONF_SSL
sed -i 's/ServerAdmin webmaster@localhost/ServerAdmin webmaster@localhost\nServerName localhost:443/' $CONF_APACHE/$CONF_AVAI/$RS1_CONF_SSL
sed -i "s/SSLCertificateFile	\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/SSLCertificateFile \/etc\/apache2\/ssl\/$SSL_APACHE_CRT/" $CONF_APACHE/$CONF_AVAI/$RS1_CONF_SSL
sed -i "s/SSLCertificateKeyFile \/etc\/ssl\/private\/ssl-cert-snakeoil.key/SSLCertificateKeyFile \/etc\/apache2\/ssl\/$SSL_APACHE_KEY/" $CONF_APACHE/$CONF_AVAI/$RS1_CONF_SSL
ok_msg "ssl conf file configured"

a2ensite $RS1_CONF_SSL
ch_err
ok_msg "$RS1_CONF_SSL enabled"

/etc/init.d/apache2 restart
ch_err
ok_msg "apache2 service restart"


## Step9 : Activate Firewall
#

echo -e "\n$CYA ACTIVATE FIREWALL ...$END\n"

FW_DIR=firewall
FW_FILE=iptables
F2B_FILE=jail.local

./$FW_DIR/$FW_FILE
ch_err
ok_msg "iptables set"
touch /var/log/apache2/server.log
ch_err
cat $FW_DIR/$F2B_FILE > /etc/fail2ban/$F2B_FILE
ch_err
cat $FW_DIR/http-get-dos.conf > /etc/fail2ban/filter.d/http-get-dos.conf
ch_err
systemctl restart fail2ban.service
ch_err
ok_msg "fail2ban set"

echo -e "\n$CYA your iptables rules are ...\n$END"
iptables -L
## Step final : remove ip provided by 42 dhcp server / it breaks the connection
#

echo -e "$RED[REMOVE MANUALLY OLD IP WITH 'ip addr del <IP> dev <INTERFACE>' and modify it with an ip of your choice, in the right range depending on the netmask]$END"
echo -e "\n$CYA REBOOT IS ADVISED FOR ALL THE CHANGES TO TAKE PLACE CORRECTLY$END"
}

main
