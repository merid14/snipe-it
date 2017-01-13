#!/bin/bash
# shellcheck disable=SC2154,SC2034
set -o nounset errexit pipefail


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
        if [ "$(dpkg-query -W -f='${Status}' "$@" 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
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
        printf "${RED}  Failed to find the OS.${NORMAL}\n"
        exit
        ;;
esac

}

## TODO: add handleing of word based branches.
# Useage compareVersions $var1 < $var2
# example compareVersions 1 3
#           return true
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
            return 0 #
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
if [ -f /etc/lsb-release ]; then
    distro="$(lsb_release -s -i -r)"
elif [ -f /etc/os-release ]; then
    distro=$(. /etc/os-release && echo $ID $VERSION_ID)
else
    distro="unsupported"
fi
}

function startApache ()
{
echo "##  Starting the apache server";
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
        printf "${RED}  Failed to find the OS.${NORMAL}\n"
        exit
        ;;
esac
}

function startMariadb ()
{
echo "##  Starting the MariaDB server";
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
        printf "${RED}  Failed to find the OS.${NORMAL}\n"
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
printf "${RED}   *************     !WARNING!   *************   !WARNING!     ************* ${NORMAL}\n"
printf "${YELLOW}                   DO NOT RUN ON A CURRENT PRODUCTION SERVER! ${NORMAL}\n"
echo
echo "    This installer assumes that you are installing on a fresh,"
echo "    blank server. It will install all the packages needed, setup the database"
echo "    and configure snipeit for you."
echo
echo "    Mail is setup separately. SELinux is assumed to be disabled."
echo "    If you have issues please include your installer log when reporting it."
echo
printf "${RED}   *************     !WARNING!   *************   !WARNING!     ************* ${NORMAL}\n"
echo
echo "    NOTICE: If you would like to see whats going on in the background "
echo "            while running the script please open a new shell and run:"
echo
echo "               tail -f /var/log/snipeit-install.log"
echo
echo "  Press enter to continue. CTRL+C to quit"
read test
}

function askDebug ()
{
    #ask to disable debug if enabled.
    ans=""
    if grep -q true "$webdir"/app/config/production/app.php; then
        until [[ $ans == "yes" ]] || [[ $ans == "no" ]]; do
        printf "${YELLOW}  Q. Debugging is currently enabled. Would you like to disable? ([Y]/n) ${NORMAL}"
        read -r debug

        shopt -s nocasematch
        case $debug in
            y | yes | "")
                sed -i "s,true,false,g" "$webdir"/app/config/production/app.php
                echo "  --  Debugging has been disabled."
                ans="yes"
                ;;
            n | no )
                printf "${RED}    Debugging is still enabled. This is not reccomended unless${NORMAL}\n"
                printf "${RED}       you are having troubles with your install.${NORMAL}\n"
                echo
                ans="no"
                ;;
            *)
                printf "${RED} --  Invalid answer. Please type y or n${NORMAL}\n"
            ;;
        esac
        done
    fi
}

function askFQDN ()
{
    echo
    printf "${YELLOW}  Q. What is the FQDN of your server? ($fqdn): ${NORMAL}"
    read -r fqdn
    if [ -z "$fqdn" ]; then
            fqdn="$(hostname --fqdn)"
    fi
    echo "      Setting to $fqdn"
    echo
}

function askDBuserpw ()
{
    until [[ $ans == "yes" ]] || [[ $ans == "no" ]]; do
    printf "${YELLOW}  Q. Do you want to automatically create the snipe database user password? (y/n) ${NORMAL}"
    read -r setpw

    shopt -s nocasematch
    case $setpw in
        y | yes )
            mysqluserpw="$(< /dev/urandom tr -dc _A-Za-z-0-9 | head -c16)"
            ans="yes"
            ;;
        n | no )
            printf "${YELLOW}   Q. What do you want your snipeit user password to be?${NORMAL}"
            read -sr mysqluserpw
            echo
            ans="no"
            ;;
        *)
            printf "${RED}      Invalid answer. Please type y or n${NORMAL}\n"
        ;;
    esac
    done
}


#####   Start Setup Functions   ####

function setupRepos ()
{
    echo
    echo "##  Adding IUS, Epel and MariaDB repos";

    echo " --  MariaDB Repo"
    if [ -f "$mariadbRepo" ]; then
        echo "      Repo already exists. $apachefile"
    else
        touch "$mariadbRepo"
        echo >> "$mariadbRepo" "[mariadb]"
        echo >> "$mariadbRepo" "name = MariaDB"
        echo >> "$mariadbRepo" "baseurl = http://yum.mariadb.org/10.0/$distro-amd64"
        echo >> "$mariadbRepo" "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB"
        echo >> "$mariadbRepo" "gpgcheck=1"
        echo >> "$mariadbRepo" "enable=1"
    fi

    echo -n " --  Epel Repo"
    ShowProgressOf yum -y -q install wget epel-release
    echo -n " --  IUS Repo"
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
        PACKAGES="git unzip curl debconf-utils apache2 mariadb-server mariadb-client
        php7.0 php7.0-mcrypt php7.0-curl php7.0-mysql php7.0-gd php7.0-mbstring
        php7.0-ldap libapache2-mod-php7.0"

        for p in $PACKAGES;do
        if isinstalled "$p"; then
            echo " --  $p Installed"
        else
            echo -n " --  $p Installing... "
            ShowProgressOf apt-get install -q -y "$p"
            echo
                if isinstalled "$p"; then
                    printf "\033[A\033[A --  $p Installing..."
                    printf "${GREEN} Installed ${NORMAL}\n"
                else
                    printf "\033[A\033[A --  $p Installing..."
                    printf "${RED} Install Failed! ${NORMAL}\n"
                    packagefailed=true
                fi
        fi
        # Check that packages were all successfully installed.
        done;
        ;;
    *centos*|*redhat*)
        echo "##  Installing packages...";
        PACKAGES="httpd MariaDB-server MariaDB-client git unzip mod_php70u php70u-mysqlnd
                php70u-bcmath php70u-cli php70u-common php70u-embedded
                php70u-gd php70u-mbstring php70u-mcrypt php70u-ldap"

        for p in $PACKAGES;do
        if isinstalled "$p"; then
            echo " --  $p Installed"
        else
            echo -n " --  $p Installing... "
            ShowProgressOf yum -y -q install "$p"
            echo
            # Check that packages were all successfully installed.
                if isinstalled "$p"; then
                    printf "\033[A\033[A --  $p Installing..."
                    printf "${GREEN} Installed ${NORMAL}\n"
                else
                    printf "\033[A\033[A --  $p Installing..."
                    printf "${RED} Install Failed! ${NORMAL}\n"
                    packagefailed=true
                fi
        fi
        done;
        ;;
    *)
        printf "${RED}  Failed to setup packages.${NORMAL}\n"
        exit
        ;;
esac

if $packagefailed; then
    printf "${RED}  Failed to setup packages.${NORMAL}\n"
    printf "${RED}  Please check install log for errors and${NORMAL}\n"
    printf "${RED}  resolve package issues before installing again.${NORMAL}\n"
    printf "${RED}  You can check the installer log back running the command:${NORMAL}\n"
    printf "${RED}  less /var/log/snipeit-install.log ${NORMAL}\n"
    exit
fi
}

function setupGitTags ()
{
    if [ -d ".git" ]; then # If git directory exists
        if [ -z "$newtag" ]; then # If newtag is empty then get the latest release
            newtag=$(git tag | grep -v 'pre' | tail -1)
        fi
        currenttag="$(basename "$(git symbolic-ref HEAD)")"
    else  # Must be a file copy install
        currenttag="$(cat "$webdir"/config/version.php | grep app | awk -F "'" '{print $4}' | cut -f1 -d"-")"
    fi
}

function setupGetFiles ()
{
    if [ "$method" = "git" ]; then
        setupGitSnipeit
    elif [ "$method" = "fc" ]; then
        setupFCSnipeit
    fi
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
    cd "$webdir" || rollbackExit
    if [ -z "$tag" ]; then
        tag="$(git tag | grep -v 'pre' | tail -1)"
    fi
    echo " --  Installing version: $tag"
    if ! $(git checkout -b "$tag" origin/"$tag" >> "$log" 2>&1); then
    #     echo >&2 message
        if ! $(git checkout -b "$tag" "$tag" >> "$log" 2>&1); then
             printf >&2 "${RED}  Failed to clone $tag.${NORMAL}\n"
             rollbackExit
        fi
    fi
    echo
}

function setupFCSnipeit ()
{
    echo "##  Downloading snipeit and extract to web directory."

    wget -P $tmp/ https://github.com/$fork/snipe-it/archive/"$file" >> "$log" 2>&1
    unzip -qo $tmp/$file -d $tmp/
    cp -R $tmp/snipe-it-$branch $webdir/$name
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
        printf "${RED}  Failed to find the apache version.${NORMAL}\n"
        rollbackExit
        ;;
esac

    if [ "$apacheversion" ]; then
        apacheaccess="Require all granted"
    else
        apacheaccess="Allow From All"
    fi

    echo "##  Creating the new virtual host in Apache";
    if [ -f "$apachefile" ]; then
        echo " --  VirtualHost already exists. $apachefile"
        echo
    else
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

if [[ "$distro" == *Ubuntu*||*Debian* ]]; then
    sudo a2dissite 000-default.conf
    sudo a2ensite "$name".conf
fi
}

function setupFiles ()
{
    setupGitTags
    echo "newtag = $newtag"
    if compareVersions "3" "$newtag"; then
        if compareVersions "3" "$currenttag"; then
            echo "  It's v3!"
            echo "  Current tag: $currenttag"
            # echo "## Configuring .env file."
            # echo > "$webdir/$name/.env" "
            # #Created By Snipe-it Installer
            # APP_TIMEZONE=$(cat /etc/timezone)
            # DB_HOST=localhost
            # DB_DATABASE=snipeit
            # DB_USERNAME=snipeit
            # DB_PASSWORD=$mysqluserpw
            # APP_URL=http://$fqdn
            # APP_KEY=$random32"
            # rollbackExit
        fi
    echo "  New Tag: $newtag"
    else
        echo "##  Modifying the $si files necessary for a production environment."
        echo " --  Setting up Timezone."

        sed -i "s,UTC,$tzone,g" "$webdir"/app/config/app.php

        echo " --  Setting up bootstrap file."
        sed -i "s,www.yourserver.com,$hostname,g" "$webdir"/bootstrap/start.php

        echo " --  Setting up database file."
        cp "$webdir"/app/config/production/database.example.php "$webdir"/app/config/production/database.php
        sed -i "s,snipeit_laravel,snipeit,g" "$webdir"/app/config/production/database.php
        sed -i "s,travis,snipeit,g" "$webdir"/app/config/production/database.php
        sed -i "s,password'  => '',password'  => '$mysqluserpw',g" "$webdir"/app/config/production/database.php

        echo " --  Setting up app file."
        cp "$webdir"/app/config/production/app.example.php "$webdir"/app/config/production/app.php
        sed -i "s,https://production.yourserver.com,http://$fqdn,g" "$webdir"/app/config/production/app.php
        sed -i "s,Change_this_key_or_snipe_will_get_ya,$appkey,g" "$webdir"/app/config/production/app.php

        # uncomment to enable debug
        #sed -i "s,false,true,g" "$webdir"/app/config/production/app.php

        # we dont need to do this right now, will implement mail config later
        # echo "  Setting up mail file."
        # cp "$webdir"/app/config/production/mail.example.php "$webdir"/app/config/production/mail.php
    fi
}

function setupDB ()
{
echo >> "$dbsetup" "CREATE DATABASE snipeit;"
echo >> "$dbsetup" "GRANT ALL PRIVILEGES ON snipeit.* TO snipeit@localhost IDENTIFIED BY '$mysqluserpw';"

startMariadb

echo
echo "##  Securing mariaDB server";
/usr/bin/mysql_secure_installation
echo

echo "##  Setting up your database"
echo -n "   Q. Enter MySQL/MariaDB root password: "
read -sr mysqlrootpw
echo

    if mysql -u root -p"$mysqlrootpw" -e 'use snipeit';then
            echo "database exists"
    elif mysql -u root -p"$mysqlrootpw" < "$dbsetup";then
        echo " --  DB setup successful."
    else
        echo "incorrect password"
    fi

# until [[ $dbnopass == "stop" ]]; do
#     result="mysql -u root -e 'use snipeit' > /dev/null 2>&1"
#     echo "result = $result"
#     if grep "1049" <<< "$result" ; then
#         echo "database missing"
#         if mysql -u root < "$dbsetup" > /dev/null 2>&1;then
#             echo " --  DB setup successful."
#             dbnopass="stop"
#             dbwpass="stop"
#         fi
#     elif grep "1045" <<< "$result" > /dev/null 2>&1; then
#         printf "${RED} --  Wrong Password!${NORMAL}\n"
#         echo -n "   Q. Enter MySQL/MariaDB root password:"
#         read -sr mysqlrootpw
#         dbnopass="stop"
#     elif grep "1007" <<< "$result" > /dev/null 2>&1; then
#         printf "${RED} --  Database already exists!${NORMAL}\n"
#         dbnopass="stop"
#         dbwpass="stop"
#     else
#         echo "not sure what the problem is"
#         echo "result = $result"
#         dbnopass="stop"
#     fi
# done
# until [[ $dbwpass == "stop" ]]; do
#     echo -n "   Q. Enter MySQL/MariaDB root password:  pw"
#     read -sr mysqlrootpw
#     result="$(mysql -u root -p"$mysqlrootpw" -e 'use snipeit' >/dev/null 2>&1)"
#     echo "$result"
#     if grep "1049" <<< "$result" ; then
#         echo "database missing pw"
#         if mysql -u root -p"$mysqlrootpw" < "$dbsetup" > /dev/null 2>&1;then
#             echo " --  DB setup successful. pw"
#         fi
#     elif grep "1045" <<< "$result" > /dev/null 2>&1; then
#         printf "${RED} --  Wrong Password!  pw${NORMAL}\n"
#         echo -n "   Q. Enter MySQL/MariaDB root password:  pw"
#         read -sr mysqlrootpw
#     elif grep "1007" <<< "$result" > /dev/null 2>&1; then
#         printf "${RED} --  Database already exists!  pw${NORMAL}\n"
#         dbwpass="stop"
#     else
#         echo "not sure what the problem is. pw"
#         echo "$result"
#         dbwpass="stop"
#     fi
# done




#     echo "##  Setting up your database."
#     if mysql -u root < "$dbsetup";then
#         echo " --  DB setup successful without password."
#     else
#         echo "##  Input your MySQL/MariaDB root password: "
#         if mysql -u root -p < "$dbsetup";then
#             echo " --  DB setup successful with password."
#         else
#             printf "${RED} --  DB setup failed.${NORMAL}\n"
#             exit
#         fi
#     fi

# result="$(mysql -u root -e 'use snipeit' 2>&1)"
# if grep "1049" <<< "$result" > /dev/null 2>&1; then
#     echo database missing no pw
#     mysql -u root < "$dbsetup"
#     stoploop="stop"
# elif grep "1045" <<< "$result" > /dev/null 2>&1; then
#     echo wrong password no pw
#     echo -n "   Q. Enter MySQL root password?"
#     read -sr mysqlrootpw
#     result="$(mysql -u root -p"$mysqlrootpw" -e 'use snipeit' 2>&1)"

# elif grep "1049" <<< "$result" > /dev/null 2>&1; then
#     echo database missing pw
#     mysql -u root -p"$mysqlrootpw" < "$dbsetup"
#     stoploop="stop"
# elif grep "1045" <<< "$result" > /dev/null 2>&1; then
#     echo  wrong password pw
# fi

# I dont think we need this anymore?
# chown root:root "$dbsetup"
# chmod 700 "$dbsetup"
#     startMariadb
# ##TODO: fix the error checking to handle a snipeit db already exists
#     echo "##  Input your MySQL/MariaDB root password  (blank if this is a fresh install): "
#     if ;then
#         echo " --  DB setup successful without password."
#     elif mysql -u root -p < "$dbsetup";then
#         echo " --  DB setup successful with password."
#     else
#         printf "${RED} --  DB setup failed.${NORMAL}\n"
#         exit
#     fi
#     echo
#     echo "##  Securing mariaDB server";
#     /usr/bin/mysql_secure_installation
#     echo
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
    curl -sS https://getcomposer.org/installer | php || exit
    php composer.phar install --no-dev --prefer-source || exit
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
    ans=""
    until [[ $ans == "yes" ]]; do
    printf "${GREEN}##  Upgrading from Version: $currenttag to Version: $newtag  ${NORMAL}\n"
    printf "${YELLOW}  Q. Would you like to continue? (y/n) ${NORMAL}"
    read -r cont
    shopt -s nocasematch
    case $cont in
            y | yes )
                echo "      Continuing with the upgrade process to version: $newtag."
                echo
                ans="yes"
                ;;
            n | no )
                echo "  Exiting now!"
                exit
                ;;
            *)
                echo "      Invalid answer. Please type y or n"
                ;;
    esac
    done
}

function setupBackup ()
{
    echo "##  Setting up backup directory."
    if [ -d "$backup" ]; then #if dir exists else create it
        echo "  --  Backup directory already exists, using it."
        echo "    $backup"
    else
        echo "    $backup"
        mkdir -p "$backup"
    fi

    echo "  --  Backing up app file."
    if [ -e "$backup"/.env ]; then
        cp -p "$webdir"/.env "$backup"
    fi
    if [ -e "$backup"/app/config/app.php ]; then
        cp -p "$webdir"/app/config/app.php "$backup"
    fi

    echo "  --  Backing up database."
    mysqldump "$name" > "$backup"/"$name".sql

    if [ ! -d "$gitdir" ]; then # If this is a file copy conversion
        echo "  --  Backing up $si folder."
        cp -p -R "$webdir" "$backup"/"$name"
        rm -rf "${webdir:?}"
    fi
}

function rollbackExit ()
{
echo "Deleting old install files."
rm -rf "$webdir"
rm -rf "${tmp:?}"
rm -rf "${tmpinstall:?}"
echo "Dropping Database."
mysql -u root -e "drop database snipeit;"
exit
}