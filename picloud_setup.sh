#!/bin/bash

#  PiCloud - Shell script for installing Owncloud on the Raspberry Pi.
# 
#  (c) Copyright 2012  Florian Müller (petrockblock@gmail.com)
# 
#  RetroPie-Setup homepage: https://github.com/petrockblog/PiCloud
# 
#  Permission to use, copy, modify and distribute PiCloud in both binary and
#  source form, for non-commercial purposes, is hereby granted without fee,
#  providing that this license information and copyright notice appear with
#  all copies and any derived work.
# 
#  This software is provided 'as-is', without any express or implied
#  warranty. In no event shall the authors be held liable for any damages
#  arising from the use of this software.
# 
#  PiCloud is freeware for PERSONAL USE only. Commercial users should
#  seek permission of the copyright holders first. Commercial use includes
#  charging money for PiCloud or software derived from PiCloud.
# 
#  The copyright holders request that bug fixes and improvements to the code
#  should be forwarded to them so everyone can benefit from the modifications
#  in future versions.
# 
#  Raspberry Pi is a trademark of the Raspberry Pi Foundation.
# 

# make sure we use the newest packages
apt-get update

# make sure that the group www-data exists
groupadd www-data
usermod -a -G www-data www-data

# install all needed packages, e.g., Apache, PHP, SQLite
apt-get install -y apache2 openssl ssl-cert libapache2-mod-php5 php5-cli php5-sqlite php5-gd php5-curl php5-common php5-cgi sqlite php-pear php-apc

# generate self-signed certificate that is valid for one year
openssl req $@ -new -x509 -days 365 -nodes -out /etc/apache2/apache.pem -keyout /etc/apache2/apache.pem
chmod 600 /etc/apache2/apache.pem

# enable Apache modules (ssl IS definitely required, I am not sure about the other two here)
a2enmod ssl
a2enmod rewrite
a2enmod headers

# configure Apache to use self-signed certificate
cp /etc/apache2/sites-available/default-ssl /etc/apache2/sites-available/default-ssl.bak
sed 's|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/apache2/apache.pem|g;s|AllowOverride None|AllowOverride All|g;s|SSLCertificateKeyFile|# SSLCertificateKeyFile|g' /etc/apache2/sites-available/default-ssl.bak >> /etc/apache2/sites-available/default-ssl

# enable SSL site
a2ensite default-ssl

# download and extract Owncloud 4.0.5 (the newest release at this time)
wget http://download.owncloud.org/releases/owncloud-4.0.5.tar.bz2
tar -xjf owncloud-4.0.5.tar.bz2
mv owncloud /var/www/
rm owncloud-4.0.5.tar.bz2

# change group and owner of all /var/www files recursively to www-data
chown -R www-data:www-data /var/www

# restart Apache service
/etc/init.d/apache2 reload

# finish the script
myipaddress=$(hostname -I | tr -d ' ')
echo -e "\n= = = = = = = = = = =\nIf everything went right, Owncloud should now be available at the URL https://$myipaddress/owncloud\n= = = = = = = = = = =\n"
