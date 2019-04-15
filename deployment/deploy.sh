#!/bin/bash

## Import lib
#

. ./lib.sh

## Error check 
#

if [ $# != 2 ]; then
	echo -e "$RED[ERROR]$END$CYA ./deploy.sh <USERNAME> <IP>$END" && exit
fi

## Variables definition
#

USER=$1
IP=$2

main() {

echo -e "$CYA LAUNCHING MAIN DEPLOY.SH ...$END\n"

## Step1 : Install, initialization / logged as root
#

echo -e "\n$CYA INSTALLING PACKAGES ...$END\n"

apt install -y vim sudo net-tools iptables-persistent fail2ban sendmail apache2 php-dev php libapache2-mod-php portsentry
ch_err
ok_msg "vim, sudo, net-tools, iptables-persistent, fail2ban, sendmail, apache2, php-dev, php, libapache2-mod-php, portsentry"

## Step2 : add user to sudo group
#

echo -e "\n$CYA USER INITIALIZATION ...$END\n"

adduser $USER sudo
ch_err
adduser $USER root
ch_err
ok_msg "$USER added to root group and sudo"

## Step3 : configure static dhcp with /30 mask
#

echo -e "\n$CYA CONFIGURING DHCP ...$END\n"

sed -i.bak 's/allow-hotplug/auto/' /etc/network/interfaces
ch_err
sed -i.bak2 "s/dhcp/static\n\taddress $IP\n\tnetmask 255.255.255.252\n\tgateway 10.13.254.254/" /etc/network/interfaces
ch_err
/etc/init.d/networking restart
ch_err
ok_msg "static dhcp configured for networking service"

## Step4 : configure ssh on port 40 and prohibit root access
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
CRON_UPDA=update_pckg
CRON_CH=ch_crontab
CRON_FOLDER=./cron
CRON_D=cron.d

cp $CRON_FOLDER/$CRON_D/$CRON_CH $CRON_PATH
ch_err
cp $CRON_FOLDER/$CRON_D/$CRON_UPDA $CRON_PATH
ch_err

if grep -E "$CRON_PATH/$CRON_UPDA" $CRONTAB | grep -v "@reboot"; then
	ok_msg "cron update pckg already present"
else
	echo "* 4	* * *	root	$CRON_PATH/$CRON_UPDA" >> $CRONTAB
	ch_err
	ok_msg "cron update pckg added"
fi

if grep -E "$CRON_PATH/$CRON_CH" $CRONTAB; then
	ok_msg "cron check modifs already present in crontab file"
else
	echo "* 0	* * *	root	$CRON_PATH/$CRON_CH" >> $CRONTAB
	ch_err
	ok_msg "cron check modifs in crontab script added to crontab"
fi

if grep -E "@reboot.*$CRON_PATH/$CRON_UPDA" $CRONTAB; then
	ok_msg "cron update pckg at reboot already present in crontab" 
else
	echo "@reboot root $CRON_PATH/$CRON_UPDA" >> $CRONTAB
	ch_err
	ok_msg "cron update pckg at reboot added"
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
FW_FILE=fw_dos_portscan_2

./$FW_DIR/$FW_FILE
ch_err
ok_msg "firewall set"


## Step10 : Activate portsentry against portscan
#

echo -e "\n$CYA ACTIVATE PORTSENTRY ...$END\n"

PORTSENTRY_CONF_1=/etc/portsentry/portsentry.conf
PORTSENTRY_CONF_2=/etc/default/portsentry

sed -i 's#BLOCK_UDP="0"#BLOCK_UDP="1"#' $PORTSENTRY_CONF_1
sed -i 's#BLOCK_TCP="0"#BLOCK_TCP="1"#' $PORTSENTRY_CONF_1
ok_msg "$PORTSENTRY_CONF_1 configured"

sed -i 's#TCP_MODE="tcp"#TCP_MODE="atcp"#' $PORTSENTRY_CONF_2
sed -i 's#UDP_MODE="udp"#UDP_MODE="audp"#' $PORTSENTRY_CONF_2
ok_msg "$PORTSENTRY_CONF_2 configured"

/etc/init.d/portsentry restart
ch_err
ok_msg "Portsentry service restarted"

## Step final : remove ip provided by 42 dhcp server / it breaks the connection
#

echo -e "$RED[REMOVE MANUALLY OLD IP WITH 'ip addr del <IP> dev <INTERFACE>']$END"
}

main


