#!/bin/bash

#  PiCloud - Shell script for installing and updating Owncloud on the Raspberry Pi.
# 
#  (c) Copyright 2012  Florian Müller (petrockblock@gmail.com)
# 
#  PiCloud homepage: https://github.com/petrockblog/PiCloud
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

printMsg()
{
	echo -e "\n= = = = = = = = = = = = = = = = = = = = =\n$1\n= = = = = = = = = = = = = = = = = = = = =\n"
}

checkNeededPackages()
{
    doexit=0
    type -P git &>/dev/null && echo "Found git command." || { echo "Did not find git. Try 'sudo apt-get install -y git' first."; doexit=1; }
    type -P dialog &>/dev/null && echo "Found dialog command." || { echo "Did not find dialog. Try 'sudo apt-get install -y dialog' first."; doexit=1; }
    if [[ doexit -eq 1 ]]; then
        exit 1
    fi
}

downloadLatestOwncloudRelease()
{
	clear
	
	if [[ ! -d /var/www/owncloud ]]; then
		echo "Cannot find directory /var/www/owncloud. "
		exit 1
	fi

	printMsg "Updating to latest Owncloud release."

	# download and extract the latest release of Owncloud (4.0.6 at this time)
	wget http://owncloud.org/releases/Changelog
	latestrelease=$(cat Changelog | grep Download | head -n 1)
	latestrelease=${latestrelease:10}
	wget "$latestrelease"
	tar -xjf "$(basename $latestrelease)"
	rm "$(basename $latestrelease)"
	rm Changelog
}

main_newinstall()
{
	clear 

	# make sure we use the newest packages
	apt-get update
	apt-get upgrade -y

	# make sure that the group www-data exists
	groupadd www-data
	usermod -a -G www-data www-data

	# install all needed packages, e.g., Apache, PHP, SQLite
	apt-get install -y apache2 openssl ssl-cert libapache2-mod-php5 php5-cli php5-sqlite php5-gd php5-curl php5-common php5-cgi sqlite php-pear php-apc git-core ca-certificates

	# perform firmware update with 240 MB RAM, and 16 MB video
	wget http://goo.gl/1BOfJ -O /usr/bin/rpi-update && chmod +x /usr/bin/rpi-update
	rpi-update 240

	# generate self-signed certificate that is valid for one year
    dialog --backtitle "PetRockBlock.com - PiCloud Setup." --msgbox "We are now going to create a self-signed certificate. You can simply press ENTER when you are asked for country name etc. or enter whatever you want." 20 60    
	clear
	openssl req $@ -new -x509 -days 365 -nodes -out /etc/apache2/apache.pem -keyout /etc/apache2/apache.pem
	chmod 600 /etc/apache2/apache.pem

	# enable Apache modules (as explained at http://owncloud.org/support/install/, Section 2.3)
	a2enmod ssl
	a2enmod rewrite
	a2enmod headers

	# disable unneccessary (for Owncloud) module(s)
	a2dismod cgi
	a2dismod authz_groupfile

	# configure Apache to use self-signed certificate
	mv /etc/apache2/sites-available/default-ssl /etc/apache2/sites-available/default-ssl.bak
	sed 's|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/apache2/apache.pem|g;s|AllowOverride None|AllowOverride All|g;s|SSLCertificateKeyFile|# SSLCertificateKeyFile|g' /etc/apache2/sites-available/default-ssl.bak > tmp
	mv tmp /etc/apache2/sites-available/default-ssl

	# limit number of parallel Apache processes
	mv /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak 
	sed 's|StartServers          5|StartServers          2|g;s|MinSpareServers       5|MinSpareServers       2|g;s|MaxSpareServers      10|MaxSpareServers       3|g' /etc/apache2/apache2.conf.bak > tmp
	mv tmp /etc/apache2/apache2.conf

	# set ARM frequency to 800 MHz (attention: should be safe, but do this at your own risk)
	echo -e "\narm_freq=800\nsdram_freq=450\ncore_freq=350" >> /boot/config.txt

	# resize swap file to 512 MB
	echo "CONF_SWAPSIZE=512" > /etc/dphys-swapfile
	dphys-swapfile setup
	dphys-swapfile swapon

	# enable SSL site
	a2ensite default-ssl

	mkdir -p /var/www/owncloud
	downloadLatestOwncloudRelease
	cp -r owncloud/* /var/www/owncloud/
	rm -rf owncloud

	# change group and owner of all /var/www files recursively to www-data
	chown -R www-data:www-data /var/www

	# restart Apache service
	/etc/init.d/apache2 reload

	# finish the script
	myipaddress=$(hostname -I | tr -d ' ')
    dialog --backtitle "PetRockBlock.com - PiCloud Setup." --msgbox "If everything went right, Owncloud should now be available at the URL https://$myipaddress/owncloud. You have to finish the setup by visiting that site. Before that, we are going to reboot the Raspberry." 20 60    
    
    reboot
}

main_update()
{
	downloadLatestOwncloudRelease
	cp -r owncloud/* /var/www/owncloud/
	rm -rf owncloud

    dialog --backtitle "PetRockBlock.com - PiCloud Setup." --msgbox "Finished upgrading Owncloud instance." 20 60    
}

# here starts the main script

checkNeededPackages

if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root. Try 'sudo ./picloud_setup'\n"
  exit 1
fi

while true; do
    cmd=(dialog --backtitle "PetRockBlock.com - PiCloud Setup." --menu "Choose task." 22 76 16)
    options=(1 "New installation"
             2 "Update existing installation")
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)    
    if [ "$choice" != "" ]; then
        case $choice in
            1) main_newinstall ;;
            2) main_update ;;
        esac
    else
        break
    fi
done
clear
