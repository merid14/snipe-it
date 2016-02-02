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
#  Set this to the branch you want to pull  ** Only for Devs ** ##TODO not working yet
branch=""

##TODO: Update docs on what the upgrade script is doing

name='snipeit'
si="Snipe-IT"
date="$(date '+%Y-%b-%d')"
backup=/opt/$name/backup/$date
webdir=/var/www/html
installed="$webdir/$name/.installed"
log="$(find /var/log/ -type f -name "snipeit-install.log")"
git="$(find $webdir/$name -type d -name ".git")"

echo "##  Checking for previous version of $si."
echo ""

if [ -z $log ] || [ -z $installed ]; then #If neither log or installer file exists
    echo "    It appears that you haven't installed $name with the installer."
    echo "    Please upgrade manually by following the instructions in the documentation."
    echo "    http://docs.snipeitapp.com/upgrading.html"
##TODO: ask if user would like to procceed anyway and prompt them to backup their files.
elif [ -d $git ]; then # If git directory exists
    cd $webdir/$name

    if [ -z $branch ];then
        branch=$(git tag | grep -v 'pre' | tail -1)
    fi
    currentBranch=$(basename $(git symbolic-ref HEAD))

    echo "##  $si install found. Version: $currentBranch"
    echo "##  Beginning the $si update process to version: $branch"
    echo ""


    if [ $currentBranch != $branch ];then
        echo "##  Setting up backup directory."
        echo "    $backup"
        echo ""
        mkdir -p $backup

        echo "##  Backing up app file."
        echo ""
        cp $webdir/$name/app/config/app.php $backup/app.php

        echo "##  Backing up database."
        echo ""
        mysqldump $name > $backup/$name.sql

        echo "##  Getting update."
        echo ""
        echo "    By default we are pulling from the latest release."
        echo "    If you pulled from another branch please upgrade manually."
        echo ""

        until [[ $ans1 == "yes" ]]; do
        echo "##  Upgrading to Version: $branch from Version: $currentBranch"
        echo ""
        echo -n "  Q. Would you like to continue? (y/n) "
        read cont
        case $cont in
                [yY] | [yY][Ee][Ss] )
                        echo "  Continuing with the upgrade process to version: $branch."
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

        set +e
        git add . >> /var/log/snipeit-install.log 2>&1
        git commit -m "Upgrading to $branch from $currentBranch" >> /var/log/snipeit-install.log 2>&1
        git stash >> /var/log/snipeit-install.log 2>&1
        git checkout -b $branch $branch >> /var/log/snipeit-install.log 2>&1
        git stash pop >> /var/log/snipeit-install.log 2>&1
        set -e

        echo "##  Cleaning cache and view directories."
        rm -rf $webdir/$name/app/storage/cache/*
        rm -rf $webdir/$name/app/storage/views/*

        echo "##  Restoring app.php file."
        cp $backup/app.php $webdir/$name/app/config/app.php

        echo "##  Running composer to apply update."
        echo ""
        sudo php composer.phar install --no-dev --prefer-source
        sudo php composer.phar dump-autoload
        sudo php artisan migrate
        echo >> $installed "Upgraded $si to version:$branch from:$currentBranch"

        echo ""
        echo "    You are now on Version $branch of $si."
    else
        echo "    You are already on the latest version."
        echo "    Version: $currentBranch"
        echo ""
    fi
fi