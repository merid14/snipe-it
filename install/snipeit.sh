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
#tmp=/tmp/snipeit && echo "$tmp" >> "$log" 2>&1
#tmpinstall=/tmp/snipe-it/install/ && echo "$tmpinstall" >> "$log" 2>&1
. "$tmpinstall"/functions.sh
clear


echo "--------------  Collect info for log  -----------------" >> "$log" 2>&1
getOSinfo

echo "--------------  Declare Variables  ---------------------" >> "$log" 2>&1
## Colors for printf
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)
## Colors for printf

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
newtag="$tag" && echo "$newtag" >> "$log" 2>&1
appkey="$(< /dev/urandom tr -dc _A-Za-z-0-9 | head -c32)" && echo "$appkey" >> "$log" 2>&1
dbsetup="$tmp"/db_setup.sql && echo "$dbsetup" >> "$log" 2>&1
mariadbRepo=/etc/yum.repos.d/MariaDB.repo && echo "$mariadbRepo" >> "$log" 2>&1

. "$tmpinstall"/functions.sh
echo "--------------  Start Installer  -----------------" >> "$log" 2>&1
showBanner

shopt -s nocasematch
case "$distro" in
    *Ubuntu*|*Debian*)
        echo "##  The installer has detected Ubuntu/Debian as the OS."
        distro=ubuntu && echo "$distro" >> "$log" 2>&1
        webdir=/var/www/"$name"/ && echo "$webdir" >> "$log" 2>&1
        gitdir="$webdir/.git" && echo "$gitdir" >> "$log" 2>&1
        apachefile=/etc/apache2/sites-available/"$name".conf && echo "$apachefile" >> "$log" 2>&1
        tzone="$(cat /etc/timezone)" && echo "$tzone" >> "$log" 2>&1
        apacheuser="www-data:www-data" && echo "$apacheuser" >> "$log" 2>&1
        apachelog="/var/log/apache2" && echo "$apachelog" >> "$log" 2>&1
        ;;
    *centos*6*|*redhat*6*)
        echo "##  The installer has detected redhat/centos 6 as the OS."
        distro=centos6 && echo "$distro" >> "$log" 2>&1
        webdir=/var/www/html/"$name"/ && echo "$webdir" >> "$log" 2>&1
        gitdir="$webdir/.git" && echo "$gitdir" >> "$log" 2>&1
        apachefile=/etc/httpd/conf.d/"$name".conf && echo "$apachefile" >> "$log" 2>&1
        tzone="$(grep ZONE /etc/sysconfig/clock | tr -d '"' | sed 's/ZONE=//g')" && echo "$tzone" >> "$log" 2>&1
        apacheuser="apache:apache" && echo "$apacheuser" >> "$log" 2>&1
        apachelog="/var/log/httpd" && echo "$apachelog" >> "$log" 2>&1
        ;;
    *centos*7*|*redhat*7*)
        echo "##  The installer has detected redhat/centos 7 as the OS."
        distro=centos7 && echo "$distro" >> "$log" 2>&1
        webdir=/var/www/html/"$name"/ && echo "$webdir" >> "$log" 2>&1
        gitdir="$webdir/.git" && echo "$gitdir" >> "$log" 2>&1
        apachefile=/etc/httpd/conf.d/"$name".conf && echo "$apachefile" >> "$log" 2>&1
        tzone="$(timedatectl | gawk -F'[: ]' ' $9 ~ /zone/ {print $11}')" && echo "$tzone" >> "$log" 2>&1
        apacheuser="apache:apache" && echo "$apacheuser" >> "$log" 2>&1
        apachelog="/var/log/httpd" && echo "$apachelog" >> "$log" 2>&1
        ;;
    *)
        printf "${RED}  The installer has detected $distro as the OS.${NORMAL}\n"
        printf "${RED}  Unfortunately this installer doesn't work on your os.${NORMAL}\n"
        printf "${RED}  Supported OS's are: $supportedos${NORMAL}\n"
        printf "${RED}  Please see snipeit docs for manual install: .${NORMAL}\n"
        printf "${RED}      http://docs.snipeitapp.com/installation/downloading.html.${NORMAL}\n"
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
        setupApacheMods
        setupDB
        setupGetFiles
        setupApacheHost
        setupFiles
        setupComposer
        setupPermissions
        setupSnipeit
        startApache
        ;;
    centos* )
        setupRepos
        setupPackages
        setupDB
        setupGetFiles
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
rm -rf "${tmp:?}"
rm -rf "${tmpinstall:?}"
cd "$webdir"
setupGitTags
echo
echo "Installed $si to version:$currenttag $date" >> "$log" 2>&1
echo
printf "${RED} The mail configuration has not been setup.${NORMAL}\n"
printf "${RED}   To setup follow the docs here:${NORMAL}\n"
echo "   http://docs.snipeitapp.com/installation/configuration.html"
echo
printf "${RED}  SELinux has not been configured. Please follow the docs here:${NORMAL}\n"
echo "     http://docs.snipeitapp.com/installation/server/linux-osx.html"
echo
echo
echo "  ***Open http://$fqdn to login to Snipe-IT.***"
exit
