#!/bin/bash
# shellcheck disable=SC2154,SC2034
#  This is a script to upgrade snipeit
#  Written by: Walter Wahlstedt (merid14)


ans=""
#cd "$webdir"/"$name" ##TODO this needs to check if the dir exists first cant exit wihout breaking the script
echo "##  Checking for  previous version of $si."
echo

if [ -f "$log" ] || [ -f "$installed" ]; then #If log or installer file exists
    cd "$webdir"/"$name" || exit
    if [ -d "$gitdir" ]; then # If git directory exists
        if [ -z "$newBranch" ]; then # If newBranch is empty then get the latest release
            newBranch=$(git tag | grep -v 'pre' | tail -1)
        fi
        currentBranch="$(basename "$(git symbolic-ref HEAD)")"

        echo "##  $si install found. Version: $currentBranch"

        if compareVersions "$currentBranch" "$newBranch"; then ##TODO Strip "v" from version name to allow number calculation

            echo "##  Beginning the $si update process to version: $newBranch"
            echo ""
            echo "    By default we are pulling from the latest release."
            echo "    If you pulled from another branch please upgrade manually."
            echo

            until [[ $ans == "yes" ]]; do
                echo "##  Upgrading to Version: $newBranch from Version: $currentBranch"
                echo ""
                echo -n "  Q. Would you like to continue? (y/n) "
                read -r cont
                shopt -s nocasematch
                case $cont in
                    y | yes )
                        echo "  Continuing with the upgrade process to version: $newBranch."
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

            if [ -d "$backup" ]; then #if dir doesnt exist
                echo "##  Backup directory already exists, using it."
                echo "    $backup"
            else
                echo "##  Setting up backup directory."
                echo "    $backup"
                echo
                mkdir -p "$backup"
            fi

            echo "##  Backing up app file."
            echo
            cp -p "$webdir"/"$name"/app/config/app.php "$backup"/

            echo "##  Backing up database."
            echo ""
            mysqldump "$name" > "$backup"/"$name".sql

            echo "##  Getting update."
            echo

            ## run git update
            cd "$webdir"/"$name" || exit
            set +e
            git add . >> "$log" 2>&1
            git commit -m "Upgrading to $newBranch from $currentBranch" >> "$log" 2>&1
            git stash >> "$log" 2>&1
            git checkout -b "$newBranch" "$newBranch" >> "$log" 2>&1
            git stash pop >> "$log" 2>&1
            set -e

            echo "##  Cleaning cache and view directories."
            rm -rf "$webdir"/"$name"/app/storage/cache/*
            rm -rf "$webdir"/"$name"/app/storage/views/*

            # rm -rf "${$webdir:?}"/"${$name:?}"/app/storage/cache/*
            # rm -rf "${$webdir:?}"/"${$name:?}"/app/storage/views/*


            echo "##  ##  Restoring app.php file."
            cp "$backup"/app.php "$webdir"/"$name"/app/config/


        else
            echo "    You are already on the latest version."
            echo "    Version: $currentBranch"
            echo
            exit
        fi
    else  # Must be a file copy install
        #get the current version
        echo -n "##  Beginning conversion from copy file install to git install."
        currentVersion="$(cat "$webdir"/"$name"/app/config/version.php | grep app | awk -F "'" '{print $4}' | cut -f1 -d"-")"

        #clone to tmp so we can check the latest version
        rm -rf "${tmp:?}/"

        ShowProgressOf git clone https://github.com/"$fork"/snipe-it "$tmp"
        cd "$tmp" || exit

        if [ -z "$newBranch" ]; then # If newBranch is empty then get the latest release
            newBranch=$(git tag | grep -v 'pre' | tail -1)
        fi
        if compareVersions "$currentVersion" "$newBranch"; then
            until [[ $ans1 == "yes" ]]; do
            echo "##  Upgrading to Version: $newBranch from Version: $currentVersion"
            echo
            echo -n "  Q. Would you like to continue? (y/n) "
            read -r cont
            shopt -s nocasematch
            case $cont in
                    y | yes )
                        echo "    Continuing with the upgrade process to version: $newBranch."
                        echo
                        ans1="yes"
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

            if [ -d "$backup" ]; then #if dir does exist
                echo "##  Backup directory already exists, using it."
                echo "    $backup"
            else
                echo "##  Setting up backup directory."
                echo "    $backup"
                echo
                mkdir -p "$backup"
            fi

            echo "##  Backing up app file."
            cp "$webdir"/"$name"/app/config/app.php "$backup"

            echo "##  Backing up $si folder."
            cp -R "$webdir"/"$name" "$backup"/"$name"
            rm -rf "${webdir:?}"/"${name:?}"

            echo "##  Backing up database."
            mysqldump "$name" > "$backup"/"$name".sql

            echo -n "##  Downloading Snipe-IT from github and put it in the web directory...";
            ShowProgressOf git clone https://github.com/"$fork"/snipe-it "$webdir"/"$name"
            # get latest stable release
            cd "$webdir"/"$name" || exit
            if [ -z "$newBranch" ]; then
                newBranch=$(git tag | grep -v 'pre' | tail -1)
            fi

            echo "    Installing version: $newBranch"
            git checkout -b "$newBranch" "$newBranch" >> "$log" 2>&1

            echo "##  Restoring files."
            echo "      Restoring app config file."
            if [ -e "$backup"/app.php ]; then
                cp "$backup"/app.php "$webdir"/"$name"/app/config/
            fi
            echo "      Restoring app production file."
            if [ -e "$backup"/"$name"/app/config/production/app.php ]; then
                cp "$backup"/"$name"/app/config/production/app.php "$webdir"/"$name"/app/config/production/
            fi
            echo "      Restoring bootstrap file."
            if [ -e "$backup"/"$name"/bootstrap/start.php ]; then
                cp "$backup"/"$name"/bootstrap/start.php "$webdir"/"$name"/bootstrap/
            fi
            echo "      Restoring database file."
            if [ -e "$backup"/"$name"/app/config/production/database.php ]; then
                cp "$backup"/"$name"/app/config/production/database.php "$webdir"/"$name"/app/config/production/
            fi
            echo "      Restoring mail file."
            if [ -e "$backup"/"$name"/app/config/production/mail.php ]; then
                cp "$backup"/"$name"/app/config/production/mail.php "$webdir"/"$name"/app/config/production/
            fi
            if compareVersions "$currentVersion" 2.1.0; then
                echo "      Restoring ldap file."
                if [ -e "$backup"/"$name"/app/config/production/ldap.php ]; then
                    cp "$backup"/"$name"/app/config/production/ldap.php "$webdir"/"$name"/app/config/production/
                fi
            fi
            echo "      Restoring composer files."
            if [ -e "$backup"/"$name"/composer.phar ]; then
                cp "$backup"/"$name"/composer.phar "$webdir"/"$name"
            fi
            if [ -d "$backup"/"$name"/vendor ]; then
                cp -r "$backup"/"$name"/vendor "$webdir"/"$name"
            fi
        else
            echo "    You are already on the latest version."
            echo "    Version: $currentBranch"
            echo
            exit
        fi
    fi
        # Change permissions on directories
        setupPermissions

        echo "##  Running composer to apply update."
        echo
        php composer.phar install --no-dev --prefer-source
        php composer.phar dump-autoload
        php artisan migrate

        echo >> "$installed" "Upgraded $si to version:$newBranch from:$currentBranch"

        echo
        echo "    You are now on Version $newBranch of $si."
        exit
else
    echo "    No previous version of $si found."
fi
