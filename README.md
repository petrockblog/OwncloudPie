PiCloud
=======

Shell script for installing and updating Owncloud on the Raspberry Pi. The script either performs a new installation of the newest Owncloud release or, if already installed, performs an upgrade to the newest release. When doing a new installation the script installs the Apache 2 webserver together with some needed Apache modules and the SQLite database package. Afterwards it downloads and installs Owncloud 4.0.5, which is the newest release at this time. 

This script was tested on the Raspbian distribution from 2012-07-15.


First of all, make sure that Git is installed:

```shell
sudo apt-get update
sudo apt-get install -y git
```

Then you can download the latest PiCloud setup script with

```shell
cd
git clone git://github.com/petrockblog/PiCloud.git
```

The script is executed with 

```shell
cd PiCloud
chmod +x picloud_setup.sh
sudo ./picloud_setup.sh
```

For more information visit the blog at http://petrockblog.wordpress.com or the repository at https://github.com/petrockblog/PiCloud.

Have fun!
