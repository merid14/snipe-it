#!/bin/bash
# shellcheck disable=SC2154,SC2034
# -----------------------------------------------------------------------------
#   Snipe-It Installer
#   Mike Tucker | mtucker6784@gmail.com
#   Walter Wahlstedt | merid14@gmail.com
#
#   This installer is for Debian and CentOS based distributions.
#   We assume you will be installing as a subdomain on a fresh OS install.
#   Mail is setup separately. SELinux is assumed to be disabled
#
#   Feel free to modify, but please givecredit where it's due. Thanks!
# -----------------------------------------------------------------------------

# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi
. /install/functions.sh

clear
log="/var/log/snipeit-install.log"

echo "--------------  Collect info for log  -----------------" >> "$log" 2>&1
getOSinfo

#  Set this to your github username to pull your changes ** Only for Devs **
logvar fork="snipe"
#  Set this to the branch you want to pull  ** Only for Devs **
logvar branch=""

echo "--------------  Declare Variables  -----------------" >> "$log" 2>&1
logvar distro="$os"
logvar os="OS: $os"
logvar arch="Arch: $arch"
logvar kernel="Kernel: $kernel"
logvar supportedos="Redhat/CentOS 6+ and Debian/Ubuntu 10.04+"
logvar name="snipeit"
logvar si="Snipe-IT"
logvar hostname="$(hostname)"
logvar fqdn="$(hostname --fqdn)"
logvar installed="$webdir/$name/.installed"
logvar tmp=/tmp/"$name"
logvar date="$(date '+%Y-%b-%d')"
logvar backup=/opt/"$name"/backup/"$date"
logvar newBranch="$branch"
logvar appkey="$(< /dev/urandom tr -dc _A-Za-z-0-9 | head -c32)"
logvar dbsetup="$tmp"/db_setup.sql
logvar mariadbRepo=/etc/yum.repos.d/MariaDB.repo

webdir=""
apachefile""
tzone=""
apacheuser=""
apachelog=""
apacheversion=""


echo "--------------  Start Installer  -----------------" >> "$log" 2>&1
showBanner

shopt -s nocasematch
case "$distro" in
    *Ubuntu*|*Debian*)
        echo "  The installer has detected Ubuntu/Debian as the OS."
        logvar distro=ubuntu
        logvar webdir=/var/www
        logvar installed="$webdir/$name/.installed"
        logvar gitdir="$webdir/$name/.git"
        logvar apachefile=/etc/apache2/sites-available/"$name".conf
        logvar tzone="$(cat /etc/timezone)";
        logvar apacheuser="www-data:www-data"
        logvar apachelog="/var/log/apache2"
        ;;
    *centos*6*|*redhat*6*)
        echo "  The installer has detected redhat/centos 6 as the OS."
        logvar distro=centos6
        logvar webdir=/var/www/html
        logvar installed="$webdir/$name/.installed"
        logvar gitdir="$webdir/$name/.git"
        logvar apachefile=/etc/httpd/conf.d/"$name".conf
        logvar tzone="$(grep ZONE /etc/sysconfig/clock | tr -d '"' | sed 's/ZONE=//g')";
        logvar apacheuser="apache:apache"
        logvar apachelog="/var/log/httpd"
        ;;
    *centos*7*|*redhat*7*)
        echo "  The installer has detected redhat/centos 7 as the OS."
        logvar distro=centos7
        logvar webdir=/var/www/html
        logvar apachefile=/etc/httpd/conf.d/"$name".conf
        logvar tzone="$(timedatectl | gawk -F'[: ]+' ' $2 ~ /Timezone/ {print $3}')";
        logvar apacheuser="apache:apache"
        logvar apachelog="/var/log/httpd"
        ;;
    *)
        echo -e "\e[31m  The installer has detected $distro as the OS.\e[0m"
        echo -e "\e[31m  Unfortunately this installer doesn't work on your os.\e[0m"
        echo -e "\e[31m  Supported OS's are: $supportedos\e[0m"
        echo -e "\e[31m  Please see snipeit docs for manual install: .\e[0m"
        echo -e "\e[31m      http://docs.snipeitapp.com/installation/downloading.html.\e[0m"
        exit
        ;;
esac

rm -rf "${$tmp:?}/"
mkdir "$tmp"

UpgradeSnipeit

askFQDN
askDBuserpw

shopt -s nocasematch
case "$distro" in
    debian|ubuntu)
        setupPackages
        startApache
        setupGitSnipeit
        setupApacheMods
        setupApacheHost
        setupFiles
        setupDB
        setupComposer
        setupPermissions
        setupSnipeit
        startApache
        ;;
    centos* )
        setupRepos
        setupPackages
        setupGitSnipeit
        setupDB
        setupApacheHost
        startApache
        setupFiles
        setupComposer
        setupPermissions
        setupSnipeit
        ##setupSELinux
        startApache
        ;;
esac

echo "##  Cleaning up..."
rm -rf "${tmp:?}/"
echo
echo >> "$installed" "Installed $si to version:$branch $date"
echo
echo -e "\e[31m The mail configuration has not been setup.\e[0m"
echo -e "\e[31m   To setup follow the docs here:\e[0m"
echo "   http://docs.snipeitapp.com/installation/configuration.html"
echo
echo -e "\e[31m  SELinux has not been configured. Please follow the docs here:\e[0m"
echo "     http://docs.snipeitapp.com/installation/server/linux-osx.html"
echo
echo
echo "  ***Open http://$fqdn to login to Snipe-IT.***"
