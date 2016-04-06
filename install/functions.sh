#!/bin/bash
# shellcheck disable=SC2154,SC2034

function ShowProgressOf ()
{
    tput civis
    "$@" >> "$log" 2>&1 &
    local pid=$!
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b\n"
    tput cnorm
}

function isinstalled ()
{
shopt -s nocasematch
case "$distro" in
    *Ubuntu*|*Debian*)
        if [ $(dpkg-query -W -f='${Status}' "$@" 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
            true
        else
            false
        fi
        ;;
    *centos*|*redhat*)
        if yum list installed "$@" >/dev/null 2>&1; then
            true
        else
            false
        fi
        ;;
    *)
        echo -e "\e[31m  Failed to find the OS.\e[0m"
        exit
        ;;
esac

}

## TODO: add handleing of word based branches.
function compareVersions ()
{
    if [[ "$1" == "$2" ]]; then
        return 2
    fi
    local IFS=.
    local i version1=(${1//[!0-9.]/}) version2=(${2//[!0-9.]/})
    # fill empty fields in version1 with zeros
    for ((i=${#version1[@]}; i<${#version2[@]}; i++)); do
        version1[i]=0
    done
    for ((i=0; i<${#version1[@]}; i++)); do
        if [[ -z ${version2[i]} ]]; then
            # fill empty fields in version2 with zeros
            version2[i]=0
        fi
        if ((10#${version1[i]} > 10#${version2[i]})); then
            return 1
        fi
        if ((10#${version1[i]} < 10#${version2[i]})); then
            return 0
        fi
    done
    return 2
}

function getOSinfo ()
{
    arch=$(uname -m)
    kernel=$(uname -r)
    if [ -f /etc/lsb-release ]; then
            os=$(lsb_release -s -d)
    elif [ -f /etc/debian_version ]; then
            os="Debian $(cat /etc/debian_version)"
    elif [ -f /etc/redhat-release ]; then
            os=$(cat /etc/redhat-release)
    else
            os="$(uname -s) $(uname -r)"
    fi

    # if [ grep -q -i 'centos\|redhat' <<<"$os" ]; then
    #     distro+="$(rpm -q --qf "%{VERSION}" "$(rpm -q --whatprovides redhat-release)")"
    # fi
}

function getDistro ()
{
    distro="$(cat /proc/version)"
    if grep -q -i 'centos\|redhat' <<<"$distro"; then
        for f in $(find /etc -type f -maxdepth 1 \( ! -wholename /etc/os-release ! -wholename /etc/lsb-release -wholename /etc/\*release -o -wholename /etc/\*version \) 2> /dev/null);
        do
            distro="${f:5:${#f}-13}"
        done;
        if [ "$distro" = "centos" ] || [ "$distro" = "redhat" ]; then
            distro+="$(rpm -q --qf "%{VERSION}" "$(rpm -q --whatprovides redhat-release)")"
        fi
    fi
}

function startApache ()
{
echo "##  Starting the apache server.";
shopt -s nocasematch
case "$distro" in
    *Ubuntu*|*Debian*)
        service apache2 restart
        ;;
    *centos*6*|*redhat*6*)
        chkconfig httpd on
        /sbin/service httpd restart
        ;;
    *centos*7*|*redhat*7*)
        systemctl enable httpd.service
        systemctl restart httpd.service
        ;;
    *)
        echo -e "\e[31m  Failed to find the OS.\e[0m"
        exit
        ;;
esac
}

function startMariadb ()
{
shopt -s nocasematch
case "$distro" in
    *Ubuntu*|*Debian*)
        service mysql restart
        ;;
    *centos*6*|*redhat*6*)
        chkconfig mysql on
        /sbin/service mysql start
        ;;
    *centos*7*|*redhat*7*)
        systemctl enable mariadb.service
        systemctl start mariadb.service
        ;;
    *)
        echo -e "\e[31m  Failed to find the OS.\e[0m"
        exit
        ;;
esac
}

function showBanner ()
{
echo "
       _____       _                  __________
      / ___/____  (_)___  ___        /  _/_  __/
      \__ \/ __ \/ / __ \/ _ \______ / /  / /
     ___/ / / / / / /_/ /  __/_____// /  / /
    /____/_/ /_/_/ .___/\___/     /___/ /_/
                /_/
"
echo
echo
echo "  Welcome to Snipe-IT Inventory Installer for $supportedos!"
echo
}

function askDebug ()
{
    #ask to disable debug if enabled.
    ans=""
    if grep -q true "$webdir"/app/config/production/app.php; then
        until [[ $ans == "yes" ]] || [[ $ans == "no" ]]; do
        echo -e -n "\e[33m  Q. Debugging is currently enabled. Would you like to disable? ([Y]/n) \e[0m"
        read -r debug

        shopt -s nocasematch
        case $debug in
            y | yes | "")
                sed -i "s,true,false,g" "$webdir"/app/config/production/app.php
                echo "    Debugging has been disabled."
                ans="yes"
                ;;
            n | no )
                echo -e "\e[31m    Debugging is still enabled. This is not reccomended unless\e[0m"
                echo -e "\e[31m       you are having troubles with your install.\e[0m"
                echo
                ans="no"
                ;;
            *)
                echo -e "\e[31m    Invalid answer. Please type y or n\e[0m"
            ;;
        esac
        done
    fi
}

function askFQDN ()
{
    echo
    echo -e -n "\e[33m  Q. What is the FQDN of your server? ($fqdn): \e[0m"
    read -r fqdn
    if [ -z "$fqdn" ]; then
            fqdn="$(hostname --fqdn)"
    fi
    echo "     Setting to $fqdn"
    echo
}

function askDBuserpw ()
{
    until [[ $ans == "yes" ]] || [[ $ans == "no" ]]; do
    echo -e -n "\e[33m  Q. Do you want to automatically create the snipe database user password? (y/n) \e[0m"
    read -r setpw

    shopt -s nocasematch
    case $setpw in
        y | yes )
            mysqluserpw="$(< /dev/urandom tr -dc _A-Za-z-0-9 | head -c16)"
            ans="yes"
            ;;
        n | no )
            echo -n  "    Q. What do you want your snipeit user password to be?"
            read -sr mysqluserpw
            echo
            ans="no"
            ;;
        *)
            echo -e "\e[31m    Invalid answer. Please type y or n\e[0m"
        ;;
    esac
    done
}


#####   Start Setup Functions   ####

function setupRepos ()
{
    echo
    echo "##  Adding IUS, epel-release and mariaDB repos.";

    if [ -f "$mariadbRepo" ]; then
        echo "    Repo already exists. $apachefile"
    else
        touch "$mariadbRepo"
        echo >> "$mariadbRepo" "[mariadb]"
        echo >> "$mariadbRepo" "name = MariaDB"
        echo >> "$mariadbRepo" "baseurl = http://yum.mariadb.org/10.0/$distro-amd64"
        echo >> "$mariadbRepo" "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB"
        echo >> "$mariadbRepo" "gpgcheck=1"
        echo >> "$mariadbRepo" "enable=1"
    fi

    ShowProgressOf yum -y -q install wget epel-release
    ShowProgressOf wget -P "$tmp"/ https://"$distro".iuscommunity.org/ius-release.rpm
    ShowProgressOf rpm -Uvh "$tmp"/ius-release*.rpm

}

function setupPackages ()
{
shopt -s nocasematch
case "$distro" in
    *Ubuntu*|*Debian*)
        export DEBIAN_FRONTEND=noninteractive
        echo
        echo -n "##  Updating..."
        ShowProgressOf apt-get update

        echo -n "##  Upgrading..."
        ShowProgressOf apt-get -q -y upgrade

        echo "##  Installing packages..."
        PACKAGES="git unzip php5 php5-mcrypt php5-curl php5-mysql php5-gd
                php5-ldap libapache2-mod-php5 curl debconf-utils apache2
                MariaDB-server MariaDB-client"

        for p in $PACKAGES;do
        if isinstalled "$p"; then
            echo " ## $p Installed"
        else
            echo -n " ## $p Installing... "
            ShowProgressOf apt-get install -q -y "$p"
            echo
        fi
        done;
        ;;
    *centos*|*redhat*)
        echo "##  Installing packages...";
        PACKAGES="httpd MariaDB-server MariaDB-client git unzip php56u php56u-mysqlnd
                php56u-bcmath php56u-cli php56u-common php56u-embedded
                php56u-gd php56u-mbstring php56u-mcrypt php56u-ldap"

        for p in $PACKAGES;do
        if isinstalled "$p"; then
            echo " ## $p Installed"
        else
            echo -n " ## $p Installing... "
            ShowProgressOf yum -y -q install "$p"
            echo
        fi
        done;
        ;;
    *)
        echo -e "\e[31m  Failed to setup packages.\e[0m"
        exit
        ;;
esac
}

function setupGitSnipeit ()
{
    echo
    echo -n "##  Cloning Snipe-IT from github to the web directory...";

    ShowProgressOf git clone https://github.com/"$fork"/snipe-it "$webdir"

    # get latest stable release
    # if [ ! -d "$webdir" ]; then
    #     mkdir -p "$webdir"
    # fi
    cd "$webdir" || exit
    if [ -z "$tag" ]; then
        tag="$(git tag | grep -v 'pre' | tail -1)"
    fi
    echo "    Installing version: $tag"
    if ! $(git checkout -b "$tag" origin/"$tag" >> "$log" 2>&1); then
    #     echo >&2 message
        if ! $(git checkout -b "$tag" "$tag" >> "$log" 2>&1); then
             echo  -e >&2 "\e[31m  Failed to clone $tag.\e[0m"
             exit
        fi
    fi

}

function setupApacheMods ()
{
    echo "##  Enabling mcrypt and rewrite"
    php5enmod mcrypt >> "$log" 2>&1
    a2enmod rewrite >> "$log" 2>&1
    ls -al /etc/apache2/mods-enabled/rewrite.load >> "$log" 2>&1
}
function setupApacheHost ()
{
shopt -s nocasematch
case "$distro" in
    *Ubuntu*|*Debian*)
        apacheversion="$(/usr/sbin/apache2 -v | grep 2.4)"
        ;;
    *centos*|*redhat*)
        apacheversion="$(apachectl -v | grep 2.4)"
        ;;
    *)
        echo -e "\e[31m  Failed to find the apache version.\e[0m"
        exit
        ;;
esac
    if [ "$apacheversion" ]; then
        apacheaccess="Require all granted"
    else
        apacheaccess="Allow From All"
    fi

    echo "##  Creating the new virtual host in Apache.";
    if [ -f "$apachefile" ]; then
        echo "    VirtualHost already exists. $apachefile"
    else
        echo "##  Setting up $si virtual host."
        echo >> "$apachefile" ""
        echo >> "$apachefile" ""
##TODO Grep if exists        echo >> $apachefile "LoadModule rewrite_module modules/mod_rewrite.so"
        echo >> "$apachefile" ""
        echo >> "$apachefile" "<VirtualHost *:80>"
        echo >> "$apachefile" "ServerAdmin webmaster@localhost"
        echo >> "$apachefile" "    <Directory $webdir/public>"
        echo >> "$apachefile" "        $apacheaccess"
        echo >> "$apachefile" "        AllowOverride All"
        echo >> "$apachefile" "        Options +Indexes"
        echo >> "$apachefile" "   </Directory>"
        echo >> "$apachefile" "    DocumentRoot $webdir/public"
        echo >> "$apachefile" "    ServerName $fqdn"
        echo >> "$apachefile" "        ErrorLog $apachelog/snipeIT.error.log"
        echo >> "$apachefile" "        CustomLog $apachelog/snipeit-access.log combined"
        echo >> "$apachefile" "</VirtualHost>"
    fi
}

function setupFiles ()
{
    echo "##  Modifying the $si files necessary for a production environment."
    echo " -- Setting up Timezone."

    sed -i "s,UTC,$tzone,g" "$webdir"/app/config/app.php

    echo " -- Setting up bootstrap file."
    sed -i "s,www.yourserver.com,$hostname,g" "$webdir"/bootstrap/start.php

    echo " -- Setting up database file."
    cp "$webdir"/app/config/production/database.example.php "$webdir"/app/config/production/database.php
    sed -i "s,snipeit_laravel,snipeit,g" "$webdir"/app/config/production/database.php
    sed -i "s,travis,snipeit,g" "$webdir"/app/config/production/database.php
    sed -i "s,password'  => '',password'  => '$mysqluserpw',g" "$webdir"/app/config/production/database.php

    echo " -- Setting up app file."
    cp "$webdir"/app/config/production/app.example.php "$webdir"/app/config/production/app.php
    sed -i "s,https://production.yourserver.com,http://$fqdn,g" "$webdir"/app/config/production/app.php
    sed -i "s,Change_this_key_or_snipe_will_get_ya,$appkey,g" "$webdir"/app/config/production/app.php

    # uncomment to enable debug
    #sed -i "s,false,true,g" "$webdir"/app/config/production/app.php

    # we dont need to do this right now, will implement mail config later
    # echo "  Setting up mail file."
    # cp "$webdir"/app/config/production/mail.example.php "$webdir"/app/config/production/mail.php
}

function setupDB ()
{
    echo "##  Setting up your database."
#store dbsetup in var instead of file
echo >> "$dbsetup" "CREATE DATABASE snipeit;"
echo >> "$dbsetup" "GRANT ALL PRIVILEGES ON snipeit.* TO snipeit@localhost IDENTIFIED BY '$mysqluserpw';"
# I dont think we need this anymore?
# chown root:root "$dbsetup"
# chmod 700 "$dbsetup"

    echo "##  Starting the mariaDB server.";
    startMariadb

    echo "##  Input your MySQL/MariaDB root password  (blank if this is a fresh install): "
##  TODO add try fail without -p and then add -p
    if mysql -u root < "$dbsetup";then
        echo "  DB setup successful without password."
    elif mysql -u root -p < "$dbsetup";then
        echo "  DB setup successful with password."
    else
        echo "  DB setup failed"
        exit
    fi

    echo "##  Securing mariaDB server.";
    /usr/bin/mysql_secure_installation
}

function setupPermissions ()
{
    echo "##  Setting permissions on web directory."
    chmod -R 755 "$webdir"/app/storage
    chmod -R 755 "$webdir"/app/private_uploads
    chmod -R 755 "$webdir"/public/uploads
    chown -R "$apacheuser" "$webdir"
}

function setupComposer ()
{
    echo "##  Installing and configuring composer"
    cd "$webdir" || exit
    curl -sS https://getcomposer.org/installer | php
    php composer.phar install --no-dev --prefer-source
}

function setupSnipeit ()
{
    echo "##  Installing Snipe-IT."
    php artisan app:install --env=production
}

# function setupSELinux ()
# {
#     #Stub for implementation

#     #TODO detect if SELinux and firewall are enabled to decide what to do
#         #Add SELinux and firewall exception/rules.
#         # Youll have to allow 443 if you want ssl connectivity.
#         # chcon -R -h -t httpd_sys_script_rw_t "$webdir"/
#         # firewall-cmd --zone=public --add-port=80/tcp --permanent
#         # firewall-cmd --reload
# }

#####   End Setup Functions   ####

function UpgradeSnipeit ()
{
    . "$tmpinstall"/upgrade.sh
}

function askUpgradeConfirm ()
{
    until [[ $ans == "yes" ]]; do
    echo -e "\e[33m##  Upgrading from Version: $currenttag to Version: $newtag  \e[0m"
    echo
    echo -e -n "\e[33m  Q. Would you like to continue? (y/n) \e[0m"
    read -r cont
    shopt -s nocasematch
    case $cont in
            y | yes )
                echo "    Continuing with the upgrade process to version: $newtag."
                echo
                ans="yes"
                ;;
            n | no )
                echo "  Exiting now!"
                exit
                ;;
            *)
                echo "    Invalid answer. Please type y or n"
                ;;
    esac
    done
}

function setupBackup ()
{
    if [ -d "$backup" ]; then #if dir exists else create it
        echo "  ##  Backup directory already exists, using it."
        echo "    $backup"
    else
        echo "  ##  Setting up backup directory."
        echo "    $backup"
        mkdir -p "$backup"
    fi

    echo "  ##  Backing up app file."
    cp -p "$webdir"/app/config/app.php "$backup"/

    echo "  ##  Backing up database."
    mysqldump "$name" > "$backup"/"$name".sql

    if [ ! -d "$gitdir" ]; then # If this is a file copy conversion
        echo "##  Backing up $si folder."
        cp -R "$webdir" "$backup"/"$name"
        rm -rf "${webdir:?}"
    fi
}