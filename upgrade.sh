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
gitDir="$(find $webdir/$name -type d -name ".git")"

echo "##  Checking for previous version of $si."
echo ""

if [ -f $log ] || [ -f $installed ]; then #If log or installer file exists
    if [ -d $gitDir ]; then # If git directory exists

        if [ -z $branch ]; then # If branch is empty then get the latest release
            branch=$(git tag | grep -v 'pre' | tail -1)
        fi
        currentBranch=$(basename $(git symbolic-ref HEAD))

        $currentVersion="$(echo $branch | sed "s,v,,g")" >> $log 2>&1
        $newVersion="$(echo $branch | sed "s,v,,g")" >> $log 2>&1
        echo "##  $si install found. Version: $currentBranch"

        if [ $currentBranch -lt $branch ]; then ##TODO Strip "v" from version name to allow number calculation

            echo "##  Beginning the $si update process to version: $branch"
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

            if [ -z $gitDir ]; then #if dir doesnt exist
                echo "##  Setting up backup directory."
                echo "    $backup"
                echo ""
                mkdir -p $backup
            else
                echo "##  Backup directory already exists, using it."
                echo "    $backup"
            fi

            echo "##  Backing up app file."
            echo ""
            cp -p $webdir/$name/app/config/app.php $backup/app.php

            echo "##  Backing up database."
            echo ""
            mysqldump $name > $backup/$name.sql

            echo "##  Getting update."
            echo ""

            ## run git update
            cd $webdir/$name
            set +e
            git add . >> $log 2>&1
            git commit -m "Upgrading to $branch from $currentBranch" >> $log 2>&1
            git stash >> $log 2>&1
            git checkout -b $branch $branch >> $log 2>&1
            git stash pop >> $log 2>&1
            set -e

            echo "##  Cleaning cache and view directories."
            rm -rf $webdir/$name/app/storage/cache/*
            rm -rf $webdir/$name/app/storage/views/*

            echo "##  ##  Restoring app.php file."
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
    else  # Must be a file copy install
        #get the current version
        $currentVersion="$(cat $webdir/$name/app/config/version.php | grep app | awk -F "'" '{print $4}' | sed "s,v,,g")"
        #clone to tmp so we can check the latest version
        git clone https://github.com/$fork/snipe-it $tmp >> $log 2>&1
        cd $tmp
        if [ -z $branch ]; then # If branch is empty then get the latest release
            branch=$(git tag | grep -v 'pre' | tail -1)
        fi
        $newVersion="$(echo $branch | sed "s,v,,g")" >> $log 2>&1
        if [ $currentVersion -le $newVersion ]; then
            if [ -z $gitDir ]; then #if dir doesnt exist
                echo "##  Setting up backup directory."
                echo "    $backup"
                echo ""
                mkdir -p $backup
            else
                echo "##  Backup directory already exists, using it."
                echo "    $backup"
            fi

            echo "##  Backing up app file."
            echo ""
            cp -p $webdir/$name/app/config/app.php $backup/app.php

            echo "##  Backing up $si folder."
            echo ""
            cp -Rp $webdir/$name $backup/$name
            rm -rf $webdir/$name

            echo "##  Backing up database."
            echo ""
            mysqldump $name > $backup/$name.sql

            begin modified install
                clone snipe-it

            echo "##  Downloading Snipe-IT from github and put it in the web directory.";
            git clone https://github.com/$fork/snipe-it $webdir/$name >> $log 2>&1
            # get latest stable release
            cd $webdir/$name
            if [ -z $branch ]; then
                branch=$(git tag | grep -v 'pre' | tail -1)
            fi

            echo "    Installing version: $branch"
            git checkout -b $branch $branch

            echo "##  Restoring app.php file."
            cp -p $backup/app.php $webdir/$name/app/config/app.php

            echo "  ##  Restoring bootstrap file."
            cp -p $backup/$name/bootstrap/start.php $webdir/$name/bootstrap/start.php

            echo "  ##  Restoring database file."
            cp -p $backup/$name/app/config/production/database.php $webdir/$name/app/config/production/database.php
## TODO Check if mail file exists
            echo "  ##  Restoring mail file."
            cp -p $backup/$name/app/config/production/mail.php $webdir/$name/app/config/production/mail.php
## TODO Check for ldap file depending on version
            echo "  ##  Restoring ldap file."
            cp -p $backup/$name/app/config/production/ldap.php $webdir/$name/app/config/production/ldap.php

            echo "##  Running composer to apply update."
            echo ""
            sudo php composer.phar install --no-dev --prefer-source
            sudo php composer.phar dump-autoload
            sudo php artisan migrate

            echo ""
            echo "    You are now on Version $branch of $si."
        else
            echo "    You are already on the latest version."
            echo "    Version: $currentBranch"
            echo ""
            exit
        fi
    fi
else
    echo " Starting Installer"
fi
