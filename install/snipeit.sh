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
set -o nounset errexit pipefail

# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi
#include functions
tmp=/tmp/snipeit && echo "$tmp" >> "$log" 2>&1
tmpinstall=/tmp/snipeit/install/ && echo "$tmpinstall" >> "$log" 2>&1
. "$tmpinstall"/functions.sh
clear


echo "--------------  Collect info for log  -----------------" >> "$log" 2>&1
getOSinfo

echo "--------------  Declare Variables  ---------------------" >> "$log" 2>&1

name="snipeit"
si="Snipe-IT"
webdir=""
apachefile=""
tzone=""
apacheuser=""
apachelog=""
apacheversion=""

distro="$os" && echo "$distro" >> "$log" 2>&1
os="OS: $os" && echo "$os" >> "$log" 2>&1
arch="Arch: $arch" && echo "$arch" >> "$log" 2>&1
kernel="Kernel: $kernel" && echo "$kernel" >> "$log" 2>&1
supportedos="Redhat/CentOS 6+ and Debian/Ubuntu 10.04+" && echo "$supportedos" >> "$log" 2>&1
log="/var/log/snipeit-install.log" && echo "$log" >> "$log" 2>&1
hostname="$(hostname)" && echo "$hostname" >> "$log" 2>&1
fqdn="$(hostname --fqdn)" && echo "$fqdn" >> "$log" 2>&1
#installed="$webdir/.installed" && echo "$installed" >> "$log" 2>&1
date="$(date '+%Y-%b-%d')" && echo "$date" >> "$log" 2>&1
backup=/opt/"$name"/backup/"$date" && echo "$backup" >> "$log" 2>&1
newBranch="$branch" && echo "$newBranch" >> "$log" 2>&1
appkey="$(< /dev/urandom tr -dc _A-Za-z-0-9 | head -c32)" && echo "$appkey" >> "$log" 2>&1
dbsetup="$tmp"/db_setup.sql && echo "$dbsetup" >> "$log" 2>&1
mariadbRepo=/etc/yum.repos.d/MariaDB.repo && echo "$mariadbRepo" >> "$log" 2>&1
. "$tmpinstall"/functions.sh
echo "--------------  Start Installer  -----------------" >> "$log" 2>&1
showBanner

shopt -s nocasematch
case "$distro" in
    *Ubuntu*|*Debian*)
        echo "  The installer has detected Ubuntu/Debian as the OS."
        distro=ubuntu && echo "$distro" >> "$log" 2>&1
        webdir=/var/www/"$name"/ && echo "$webdir" >> "$log" 2>&1
        gitdir="$webdir/.git" && echo "$gitdir" >> "$log" 2>&1
        apachefile=/etc/apache2/sites-available/"$name".conf && echo "$apachefile" >> "$log" 2>&1
        tzone="$(cat /etc/timezone)" && echo "$tzone" >> "$log" 2>&1
        apacheuser="www-data:www-data" && echo "$apacheuser" >> "$log" 2>&1
        apachelog="/var/log/apache2" && echo "$apachelog" >> "$log" 2>&1
        ;;
    *centos*6*|*redhat*6*)
        echo "  The installer has detected redhat/centos 6 as the OS."
        distro=centos6 && echo "$distro" >> "$log" 2>&1
        webdir=/var/www/html/"$name"/ && echo "$webdir" >> "$log" 2>&1
        gitdir="$webdir/.git" && echo "$gitdir" >> "$log" 2>&1
        apachefile=/etc/httpd/conf.d/"$name".conf && echo "$apachefile" >> "$log" 2>&1
        tzone="$(grep ZONE /etc/sysconfig/clock | tr -d '"' | sed 's/ZONE=//g')" && echo "$tzone" >> "$log" 2>&1
        apacheuser="apache:apache" && echo "$apacheuser" >> "$log" 2>&1
        apachelog="/var/log/httpd" && echo "$apachelog" >> "$log" 2>&1
        ;;
    *centos*7*|*redhat*7*)
        echo "  The installer has detected redhat/centos 7 as the OS."
        distro=centos7 && echo "$distro" >> "$log" 2>&1
        webdir=/var/www/html/"$name"/ && echo "$webdir" >> "$log" 2>&1
        gitdir="$webdir/.git" && echo "$gitdir" >> "$log" 2>&1
        apachefile=/etc/httpd/conf.d/"$name".conf && echo "$apachefile" >> "$log" 2>&1
        tzone="$(timedatectl | gawk -F'[: ]+' ' $2 ~ /Timezone/ {print $3}')" && echo "$tzone" >> "$log" 2>&1
        apacheuser="apache:apache" && echo "$apacheuser" >> "$log" 2>&1
        apachelog="/var/log/httpd" && echo "$apachelog" >> "$log" 2>&1
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
. "$tmpinstall"/functions.sh
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
# echo >> "$installed" "Installed $si to version:$branch $date"
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
