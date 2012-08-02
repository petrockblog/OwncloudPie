PiCloud
=======

Shell script for installing Owncloud on the Raspberry Pi

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
./picloud_setup.sh
```

The script installs the Apache 2 webserver together with some needed Apache modules and the SQLite database package. Afterwards it downloads and installs Owncloud 4.0.5, which is the newest release at this time. 

For more information visit the blog at http://petrockblog.wordpress.com or the repository at https://github.com/petrockblog/PiCloud.

Have fun!
