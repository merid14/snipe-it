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
#branch="develop"

##TODO: Update docs on what the upgrade script is doing

name='snipeit'
si="Snipe-IT"
setbranch=1
date="$(date '+%Y-%b-%d')"
backup=/opt/$name/backup/$date
webdir=/var/www/html
installed="$webdir/$name/.installed"
log="$(find /var/log/ -type f -name "snipeit-install.log")"

echo "##  Checking for previous version of $si."
echo ""

if [ ! $log ] || [ ! $installed ]
then
    echo "    It appears that you haven't installed $name with the installer."
    echo "    Please upgrade manually by following the instructions in the documentation."
    echo "    http://docs.snipeitapp.com/upgrading.html"
##TODO: ask if user would like to procceed anyway and prompt them to backup their files.
else
    echo "##  $si install found."
    echo "##  Beginning the $si update process."
    echo ""

echo "##  Setting up backup directory."
echo "    $backup"
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
cd $webdir/$name

# until [[ $ans == "yes" ]]; do
#     echo "  Q. What branch would you like to use to upgrade?"
#     echo ""
#     echo "    1. Latest Release (default)"
#     echo "    2. Master"
#     echo "    3. Develop"
#     echo ""
#     read setbranch
#     echo " setbranch equals $setbranch." ## for debug
#     case $setbranch in
#         1 || '')
#             branch=$(git tag | grep -v 'pre' | tail -1)
#             echo "  Branch has been set to latest release. $branch"
#             ans="yes"
#             ;;
#         2)
#             branch="master"
#             echo "  Branch has been set to $branch."
#             ans="yes"
#             ;;
#         3)
#             branch="develop"
#             echo "  Branch has been set to $branch."
#             ans="yes"
#             ;;
#         4)
#             echo -n "    Please type in the branch you would like to use:"
#             read branch
#             echo "  Branch has been set to $branch."
#             ans="yes"
#             ;;
#         *)
#             echo "  Invalid answer. Please select the number for the branch you want."
#             ;;
#     esac
# done
branch=$(git tag | grep -v 'pre' | tail -1)
branch=v2.0.6
currentBranch=$(basename $(git symbolic-ref HEAD))

if [ $currentBranch=$branch ]
then
    echo "    You are already on the latest version."
    echo "    Version: $currentBranch"
else
    git add -p
    git commit
    git stash
    git checkout other-branch
    git stash pop
    git checkout -b $branch $branch
    echo >> $installed "Upgraded $si to version:$branch from:$currentBranch"
fi

echo "##  Cleaning cache and view directories."
echo ""
rm -rf $webdir/$name/app/storage/cache/*
rm -rf $webdir/$name/app/storage/views/*

echo "##  Restoring app.php file."
cp $backup/app.php $webdir/$name/app/config/app.php

echo "##  Running composer to apply update."
echo ""
sudo php composer.phar install --no-dev --prefer-source
sudo php composer.phar dump-autoload
sudo php artisan migrate
fi