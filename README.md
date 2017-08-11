OwncloudPie
===========

Shell script for installing and updating Owncloud on the Raspberry Pi. The script either performs a new installation of the newest Owncloud release or, if already installed, performs an upgrade to the newest release. When doing a new installation, you can choose between the Apache 2 or the NGiNX webserver. 

The script downloads and installs the latest Owncloud version that can be found in the file at http://owncloud.org/releases/Changelog. 

## Quick Start

If you don't want to enter multiple commands, just copy and paste the string below into your Terminal:

```shell
sudo apt-get update && sudo apt-get install -y git dialog && git clone git://github.com/petrockblog/OwncloudPie.git && cd OwncloudPie && chmod +x owncloudpie_setup.sh && chmod +x owncloudpie_setup.sh && sudo ./owncloudpie_setup.sh
```

## Usage

First of all, make sure that Git is installed:

```shell
sudo apt-get update
sudo apt-get install -y git dialog
```

Then you can download the latest OwncloudPie setup script with

```shell
cd
git clone git://github.com/petrockblog/OwncloudPie.git
```

The script is executed with 

```shell
cd OwncloudPie
chmod +x owncloudpie_setup.sh
sudo ./owncloudpie_setup.sh
```

For more information visit the blog at http://petrockblog.wordpress.com or the repository at https://github.com/petrockblog/OwncloudPie.

Have fun!
