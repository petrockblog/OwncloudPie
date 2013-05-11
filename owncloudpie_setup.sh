#!/bin/bash

#  OwncloudPie - Shell script for installing and updating Owncloud on the Raspberry Pi.
# 
#  (c) Copyright 2012  Florian Müller (petrockblock@gmail.com)
# 
#  OwncloudPie homepage: https://github.com/petrockblog/OwncloudPie
# 
#  Permission to use, copy, modify and distribute OwncloudPie in both binary and
#  source form, for non-commercial purposes, is hereby granted without fee,
#  providing that this license information and copyright notice appear with
#  all copies and any derived work.
# 
#  This software is provided 'as-is', without any express or implied
#  warranty. In no event shall the authors be held liable for any damages
#  arising from the use of this software.
# 
#  OwncloudPie is freeware for PERSONAL USE only. Commercial users should
#  seek permission of the copyright holders first. Commercial use includes
#  charging money for OwncloudPie or software derived from OwncloudPie.
# 
#  The copyright holders request that bug fixes and improvements to the code
#  should be forwarded to them so everyone can benefit from the modifications
#  in future versions.
# 
#  Raspberry Pi is a trademark of the Raspberry Pi Foundation.
# 

function printMsg()
{
	echo -e "\n= = = = = = = = = = = = = = = = = = = = =\n$1\n= = = = = = = = = = = = = = = = = = = = =\n"
}

# arg 1: key, arg 2: value, arg 3: file
function ensureKeyValue()
{
    if [[ -z $(egrep -i ";? *$1 = [0-9]*[M]?" $3) ]]; then
        # add key-value pair
        echo "$1 = $2" >> $3
    else
        # replace existing key-value pair
        toreplace=`egrep -i ";? *$1 = [0-9]*[M]?" $3`
        sed $3 -i -e "s|$toreplace|$1 = $2|g"
    fi     
}

# arg 1: key, arg 2: value, arg 3: file
# make sure that a key-value pair is set in file
# key=value
function ensureKeyValueShort()
{
    if [[ -z $(egrep -i "#? *$1\s?=\s?""?[+|-]?[0-9]*[a-z]*"""? $3) ]]; then
        # add key-value pair
        echo "$1=""$2""" >> $3
    else
        # replace existing key-value pair
        toreplace=`egrep -i "#? *$1\s?=\s?""?[+|-]?[0-9]*[a-z]*"""? $3`
        sed $3 -i -e "s|$toreplace|$1=""$2""|g"
    fi     
}

function checkNeededPackages()
{
    doexit=0
    type -P git &>/dev/null && echo "Found git command." || { echo "Did not find git. Try 'sudo apt-get install -y git' first."; doexit=1; }
    type -P dialog &>/dev/null && echo "Found dialog command." || { echo "Did not find dialog. Try 'sudo apt-get install -y dialog' first."; doexit=1; }
    if [[ doexit -eq 1 ]]; then
        exit 1
    fi
}

function downloadLatestOwncloudRelease()
{
	clear
	
	if [[ ! -d /var/www/owncloud ]]; then
		echo "Cannot find directory /var/www/owncloud. "
		exit 1
	fi

	printMsg "Updating to latest Owncloud release."

	# download and extract the latest release of Owncloud (4.5.2 at this time)
	wget http://owncloud.org/releases/Changelog
	latestrelease=$(cat Changelog | grep Download | head -n 1)
	latestrelease=${latestrelease:10}
	wget "$latestrelease"
	tar -xjf "$(basename $latestrelease)"
	rm "$(basename $latestrelease)"
	rm Changelog
}

function writeServerConfig()
{
	cat > /etc/nginx/sites-available/default << _EOF_
# owncloud
server {
  listen 80;
    server_name $__servername;
    rewrite ^ https://\$server_name\$request_uri? permanent;  # enforce https
}

# owncloud (ssl/tls)
server {
  listen 443 ssl;
  server_name $__servername;
  ssl_certificate /etc/nginx/cert.pem;
  ssl_certificate_key /etc/nginx/cert.key;
  root /var/www;
  index index.php;
  client_max_body_size 1000M; # set maximum upload size
  fastcgi_buffers 64 4K;

  # deny direct access
  location ~ ^/owncloud/(data|config|\.ht|db_structure\.xml|README) {
    deny all;
  }

  # default try order
  location / {
    try_files \$uri \$uri/ index.php;
  }

  # owncloud WebDAV
  location @webdav {
    fastcgi_split_path_info ^(.+\.php)(/.*)$;
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_param HTTPS on;
    include fastcgi_params;
  }

  # enable php
  location ~ ^(?<script_name>.+?\.php)(?<path_info>/.*)?$ {
    try_files \$script_name = 404;
    include fastcgi_params;
    fastcgi_param PATH_INFO \$path_info;
    fastcgi_param HTTPS on;
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_read_timeout 900s; # 15 minutes
  }
}    
_EOF_
}

function main_setservername()
{
    cmd=(dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --inputbox "Please enter the URL of your Owncloud server." 22 76 16)
    choices=$("${cmd[@]}" 2>&1 >/dev/tty)    
    if [ "$choices" != "" ]; then
        __servername=$choices

        if [[ -f /etc/nginx/sites-available/default ]]; then
          sed /etc/nginx/sites-available/default -i -r -e "s|server_name [a-zA-Z.]+|server_name $__servername|g"
        fi

    else
        break
    fi  
}

function main_newinstall_nginx()
{
	clear 

	# make sure we use the newest packages
	apt-get update
	apt-get upgrade -y

	# make sure that the group www-data exists
	groupadd www-data
	usermod -a -G www-data www-data

	# install all needed packages, e.g., Apache, PHP, SQLite
  apt-get remove -y apache2
  apt-get install -y nginx sendmail sendmail-bin openssl ssl-cert php5-cli php5-sqlite php5-gd php5-curl php5-common php5-cgi sqlite php-pear php-apc git-core
  apt-get install -y autoconf automake autotools-dev curl libapr1 libtool curl libcurl4-openssl-dev php-xml-parser php5 php5-dev php5-gd php5-fpm
  apt-get install -y memcached php5-memcache varnish dphys-swapfile
  apt-get autoremove -y

	# set memory split to 240 MB RAM and 16 MB video
  ensureKeyValueShort "gpu_mem" "16" "/boot/config.txt"

	# generate self-signed certificate that is valid for one year
  dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --msgbox "We are now going to create a self-signed certificate. While you could simply press ENTER when you are asked for country name etc. or enter whatever you want, it might be beneficial to have the web servers host name in the common name field of the certificate." 20 60    

	openssl req $@ -new -x509 -days 365 -nodes -out /etc/nginx/cert.pem -keyout /etc/nginx/cert.key
	chmod 600 /etc/nginx/cert.pem
	chmod 600 /etc/nginx/cert.key

	writeServerConfig
	sed /etc/php5/fpm/pool.d/www.conf -i -e "s|listen = /var/run/php5-fpm.sock|listen = 127.0.0.1:9000|g"

  ensureKeyValue "upload_max_filesize" "1000M" "/etc/php5/fpm/php.ini"
  ensureKeyValue "post_max_size" "1000M" "/etc/php5/fpm/php.ini"

  ensureKeyValue "upload_tmp_dir" "/srv/http/owncloud/data" "/etc/php5/fpm/php.ini"
  mkdir -p /srv/http/owncloud/data
  chown www-data:www-data /srv/http/owncloud/data

  sed /etc/nginx/sites-available/default -i -e "s|client_max_body_size [0-9]*[M]?;|client_max_body_size 1000M;|g"

	/etc/init.d/php5-fpm restart
	/etc/init.d/nginx restart

	# set ARM frequency to 800 MHz (or use the raspi-config tool to set clock speed)
  ensureKeyValueShort "arm_freq" "800" "/boot/config.txt"
  ensureKeyValueShort "sdram_freq" "400" "/boot/config.txt"
  ensureKeyValueShort "core_freq" "250" "/boot/config.txt"

	# resize swap file to 512 MB
  ensureKeyValueShort "CONF_SWAPSIZE" "512" "/etc/dphys-swapfile"
	dphys-swapfile setup
	dphys-swapfile swapon

  mkdir -p /var/www/owncloud
  downloadLatestOwncloudRelease
	mv owncloud/ /var/www/

	# change group and owner of all /var/www files recursively to www-data
	chown -R www-data:www-data /var/www

  # enable US UTF-8 locale
  sudo sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen

	# finish the script
	myipaddress=$(hostname -I | tr -d ' ')
  dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --msgbox "If everything went right, Owncloud should now be available at the URL https://$myipaddress/owncloud. You have to finish the setup by visiting that site." 20 60    
}

function main_newinstall_apache()
{
  clear 

  # make sure we use the newest packages
  apt-get update
  apt-get upgrade -y

  # make sure that the group www-data exists
  groupadd www-data
  usermod -a -G www-data www-data

  # install all needed packages, e.g., Apache, PHP, SQLite
  apt-get install -y apache2 openssl sendmail sendmail-bin ssl-cert libapache2-mod-php5 php5-cli php5-sqlite php5-gd php5-curl php5-common php5-cgi sqlite php-pear php-apc git-core ca-certificates dphys-swapfile

  # Change RAM settings 16 MB video RAM
  ensureKeyValueShort "gpu_mem" "16" "/boot/config.txt"

  # generate self-signed certificate that is valid for one year
  dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --msgbox "We are now going to create a self-signed certificate. While you could simply press ENTER when you are asked for country name etc. or enter whatever you want, it might be beneficial to have the web servers host name in the common name field of the certificate." 20 60    
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
  ensureKeyValueShort "arm_freq" "800" "/boot/config.txt"
  ensureKeyValueShort "sdram_freq" "450" "/boot/config.txt"
  ensureKeyValueShort "core_freq" "350" "/boot/config.txt"

  # resize swap file to 512 MB
  ensureKeyValueShort "CONF_SWAPSIZE" "512" "/etc/dphys-swapfile"
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

  # enable US UTF-8 locale
  sudo sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen

  # finish the script
  myipaddress=$(hostname -I | tr -d ' ')
  dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --msgbox "If everything went right, Owncloud should now be available at the URL https://$myipaddress/owncloud. You have to finish the setup by visiting that site. Before that, we are going to reboot the Raspberry." 20 60    
    
  reboot
}

function main_update()
{
	downloadLatestOwncloudRelease
	cp -r owncloud/* /var/www/owncloud/
	rm -rf owncloud

  chown -R www-data:www-data /var/www

    dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --msgbox "Finished upgrading Owncloud instance." 20 60    
}

function main_updatescript()
{
  scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  pushd $scriptdir
  if [[ ! -d .git ]]; then
    dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --msgbox "Cannot find direcotry '.git'. Please clone the OwncloudPie script via 'git clone git://github.com/petrockblog/OwncloudPie.git'" 20 60    
    popd
    return
  fi
  git pull
  popd
  dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --msgbox "Fetched the latest version of the OwncloudPie script. You need to restart the script." 20 60    
}

# here starts the main script

checkNeededPackages

if [[ -f /etc/nginx/sites-available/default ]]; then
  __servername=$(egrep -m 1 "server_name " /etc/nginx/sites-available/default | sed "s| ||g")
  __servername=${__servername:11:0-1}
else
  __servername="url.ofmyserver.com"
fi

if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root. Try 'sudo ./OwncloudPie_setup'\n"
  exit 1
fi

while true; do
    cmd=(dialog --backtitle "PetRockBlock.com - OwncloudPie Setup." --menu "You MUST set the server URL (e.g., 192.168.0.10 or myaddress.dyndns.org) before starting one of the installation routines. Choose task:" 22 76 16)
    options=(1 "Set server URL ($__servername)"
             2 "New installation, NGiNX based"
             3 "New installation, Apache based"
             4 "Update existing Owncloud installation"
             5 "Update OwncloudPie script")
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)    
    if [ "$choice" != "" ]; then
        case $choice in
            1) main_setservername ;;
            2) main_newinstall_nginx ;;
            3) main_newinstall_apache ;;
            4) main_update ;;
            5) main_updatescript ;;
        esac
    else
        break
    fi
done
clear
