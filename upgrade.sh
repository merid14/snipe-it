#!/bin/bash

#  This is a script to upgrade snipeit
#  Written by: Walter Wahlstedt (merid14)

set -e
# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi

clear
#  Set this to your github username to pull your changes ** Only for Devs **
fork="snipe"
#  Set this to the branch you want to pull  ** Only for Devs **
branch=""

##TODO: Update docs on what the upgrade script is doing

name='snipeit'
si="Snipe-IT"
date="$(date '+%Y-%b-%d')"
backup=/opt/$name/backup/$date
webdir=/var/www/html
installed="$webdir/$name/.installed"
log="/var/log/snipeit-install.log"
tmp=/tmp/$name
gitDir="$webdir/$name/.git"
newBranch=$branch

####################  Functions Go Here  ######################
function ShowProgressOf()
{
    tput civis
    "$@" >> $log 2>&1 &
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

function isinstalled
{
    if yum list installed "$@" >/dev/null 2>&1; then
        true
    else
        false
    fi
}

function compareVersions ()
{
    if [[ $1 == $2 ]]; then
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
####################    Functions End     ######################

cd $webdir/$name
echo "##  Checking for previous version of $si."
echo ""

if [ -f $log ] || [ -f $installed ]; then #If log or installer file exists
    if [ -d $gitDir ]; then # If git directory exists

        if [ -z $newBranch ]; then # If newBranch is empty then get the latest release
            newBranch=$(git tag | grep -v 'pre' | tail -1)
        fi
        currentBranch=$(basename $(git symbolic-ref HEAD))

        echo "##  $si install found. Version: $currentBranch"

        if compareVersions $currentBranch $newBranch; then ##TODO Strip "v" from version name to allow number calculation

            echo "##  Beginning the $si update process to version: $newBranch"
            echo ""
            echo "    By default we are pulling from the latest release."
            echo "    If you pulled from another branch please upgrade manually."
            echo ""

            until [[ $ans1 == "yes" ]]; do
            echo "##  Upgrading to Version: $newBranch from Version: $currentBranch"
            echo ""
            echo -n "  Q. Would you like to continue? (y/n) "
            read cont
            case $cont in
                    [yY] | [yY][Ee][Ss] )
                            echo "  Continuing with the upgrade process to version: $newBranch."
                            echo ""
                            ans1="yes"
                            ;;
                    [nN] | [n|N][O|o] )
                            echo "  Exiting now!"
                            exit
                            ;;
                    *)      echo "    Invalid answer. Please type y or n"
                            ;;
            esac
            done

            if [ -d $backup ]; then #if dir doesnt exist
                echo "##  Backup directory already exists, using it."
                echo "    $backup"
            else
                echo "##  Setting up backup directory."
                echo "    $backup"
                echo ""
                mkdir -p $backup
            fi

            echo "##  Backing up app file."
            echo ""
            cp -p $webdir/$name/app/config/app.php $backup/

            echo "##  Backing up database."
            echo ""
            mysqldump $name > $backup/$name.sql

            echo "##  Getting update."
            echo ""

            ## run git update
            cd $webdir/$name
            set +e
            git add . >> $log 2>&1
            git commit -m "Upgrading to $newBranch from $currentBranch" >> $log 2>&1
            git stash >> $log 2>&1
            git checkout -b $newBranch $newBranch >> $log 2>&1
            git stash pop >> $log 2>&1
            set -e

            echo "##  Cleaning cache and view directories."
            rm -rf $webdir/$name/app/storage/cache/*
            rm -rf $webdir/$name/app/storage/views/*

            echo "##  ##  Restoring app.php file."
            cp $backup/app.php $webdir/$name/app/config/


        else
            echo "    You are already on the latest version."
            echo "    Version: $currentBranch"
            echo ""
            exit
        fi
    else  # Must be a file copy install
        #get the current version
        echo -n "##  Beginning conversion from copy file install to git install."
        currentVersion="$(cat $webdir/$name/app/config/version.php | grep app | awk -F "'" '{print $4}' | cut -f1 -d"-")"

        #clone to tmp so we can check the latest version
        if [ -d $tmp ]; then # If directory already exists
            rm -rf $tmp
        fi

        ShowProgressOf git clone https://github.com/$fork/snipe-it $tmp
        cd $tmp

        if [ -z $newBranch ]; then # If newBranch is empty then get the latest release
            newBranch=$(git tag | grep -v 'pre' | tail -1)
        fi
        if compareVersions $currentVersion $newBranch; then
            until [[ $ans1 == "yes" ]]; do
            echo "##  Upgrading to Version: $newBranch from Version: $currentVersion"
            echo ""
            echo -n "  Q. Would you like to continue? (y/n) "
            read cont
            case $cont in
                    [yY] | [yY][Ee][Ss] )
                            echo "    Continuing with the upgrade process to version: $newBranch."
                            echo ""
                            ans1="yes"
                            ;;
                    [nN] | [n|N][O|o] )
                            echo "  Exiting now!"
                            exit
                            ;;
                    *)      echo "    Invalid answer. Please type y or n"
                            ;;
            esac
            done

            if [ -d $backup ]; then #if dir does exist
                echo "##  Backup directory already exists, using it."
                echo "    $backup"
            else
                echo "##  Setting up backup directory."
                echo "    $backup"
                echo ""
                mkdir -p $backup
            fi

            echo "##  Backing up app file."
            cp $webdir/$name/app/config/app.php $backup

            echo "##  Backing up $si folder."
            cp -R $webdir/$name $backup/$name
            rm -rf $webdir/$name

            echo "##  Backing up database."
            mysqldump $name > $backup/$name.sql

            echo -n "##  Downloading Snipe-IT from github and put it in the web directory...";
            ShowProgressOf git clone https://github.com/$fork/snipe-it $webdir/$name
            # get latest stable release
            cd $webdir/$name
            if [ -z $newBranch ]; then
                newBranch=$(git tag | grep -v 'pre' | tail -1)
            fi

            echo "    Installing version: $newBranch"
            git checkout -b $newBranch $newBranch >> $log 2>&1

            echo "##  Restoring files."
            echo "      Restoring app config file."
            if [ -e $backup/app.php ]; then
                cp $backup/app.php $webdir/$name/app/config/
            fi
            echo "      Restoring app production file."
            if [ -e $backup/$name/app/config/production/app.php ]; then
                cp $backup/$name/app/config/production/app.php $webdir/$name/app/config/production/
            fi
            echo "      Restoring bootstrap file."
            if [ -e $backup/$name/bootstrap/start.php ]; then
                cp $backup/$name/bootstrap/start.php $webdir/$name/bootstrap/
            fi
            echo "      Restoring database file."
            if [ -e $backup/$name/app/config/production/database.php ]; then
                cp $backup/$name/app/config/production/database.php $webdir/$name/app/config/production/
            fi
            echo "      Restoring mail file."
            if [ -e $backup/$name/app/config/production/mail.php ]; then
                cp $backup/$name/app/config/production/mail.php $webdir/$name/app/config/production/
            fi
            if compareVersions $currentVersion 2.1.0; then
                echo "      Restoring ldap file."
                if [ -e $backup/$name/app/config/production/ldap.php ]; then
                    cp $backup/$name/app/config/production/ldap.php $webdir/$name/app/config/production/
                fi
            fi
            echo "      Restoring composer files."
            if [ -e $backup/$name/composer.phar ]; then
                cp $backup/$name/composer.phar $webdir/$name
            fi
            if [ -d $backup/$name/vendor ]; then
                cp -r $backup/$name/vendor $webdir/$name
            fi
        else
            echo "    You are already on the latest version."
            echo "    Version: $currentBranch"
            echo ""
            exit
        fi
    fi
            # Change permissions on directories
            echo "##  Setting permissions on web directory."
            chmod -R 755 $webdir/$name/app/storage
            chmod -R 755 $webdir/$name/app/private_uploads
            chmod -R 755 $webdir/$name/public/uploads
            chown -R apache:apache $webdir/$name

            chmod -R 750 $backup
            chown -R root:root $backup

            echo "##  Running composer to apply update."
            echo ""
            php composer.phar install --no-dev --prefer-source
            php composer.phar dump-autoload
            php artisan migrate

            echo >> $installed "Upgraded $si to version:$newBranch from:$currentBranch"

            echo ""
            echo "    You are now on Version $newBranch of $si."
else
    echo " Starting Installer"
fi
