#!/bin/bash
# shellcheck disable=SC2154,SC2034
#  This is a script to upgrade snipeit
#  Written by: Walter Wahlstedt (merid14)


ans=""
#cd "$webdir" ##TODO this needs to check if the dir exists first cant exit wihout breaking the script
echo
echo "##  Checking for  previous version of $si."


if [ -d "$webdir" ]; then #If webdir exists
    cd "$webdir" || exit

    if [ -d "$gitdir" ]; then # If git directory exists
        if [ -z "$newtag" ]; then # If newtag is empty then get the latest release
            newtag=$(git tag | grep -v 'pre' | tail -1)
        fi
        currenttag="$(basename "$(git symbolic-ref HEAD)")"

        echo -e "\e[33m##  $si install found. Version: $currenttag\e[0m"

        if compareVersions "$currenttag" "$newtag"; then ##TODO Strip "v" from version name to allow number calculation

            echo "##  Beginning the $si update process to version: $newtag"
            echo ""
            echo "    By default we are pulling from the latest release."
            echo "    If you pulled from another branch/tag please upgrade manually."
            echo

            until [[ $ans == "yes" ]]; do
                echo "##  Upgrading to Version: $newtag from Version: $currenttag"
                echo ""
                echo -e "\e[33m  Q. Would you like to continue? (y/n) \e[0m"
                read -r cont
                shopt -s nocasematch
                case $cont in
                    y | yes )
                        echo "  Continuing with the upgrade process to version: $newtag."
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

            echo "  ##  Getting update."

            ## run git update
            cd "$webdir" || exit
            set +e
            git add . >> "$log" 2>&1
            git commit -m "Upgrading to $newtag from $currenttag" >> "$log" 2>&1
            git stash >> "$log" 2>&1
            git checkout -b "$newtag" "$newtag" >> "$log" 2>&1
            git stash pop >> "$log" 2>&1
            set -e

            echo "  ##  Cleaning cache and view directories."
            rm -rf "$webdir"/app/storage/cache/*
            rm -rf "$webdir"/app/storage/views/*

            # rm -rf "${$webdir:?}"/"${$name:?}"/app/storage/cache/*
            # rm -rf "${$webdir:?}"/"${$name:?}"/app/storage/views/*


            echo "  ##  Restoring app.php file."
            cp "$backup"/app.php "$webdir"/app/config/


        else
            echo
            echo -e "\e[32m    You are already on the latest version.\e[0m"
            echo -e "\e[32m    Version: $currenttag\e[0m"
            echo
            exit
        fi
    else  # Must be a file copy install
        #get the current version
        echo -n "##  Beginning conversion from copy file install to git install."
        currenttag="$(cat "$webdir"/app/config/version.php | grep app | awk -F "'" '{print $4}' | cut -f1 -d"-")"

        #clone to tmp so we can check the latest version
        rm -rf "${tmp:?}"
        git clone -q https://github.com/"$fork"/snipe-it "$tmp" || { echo >&2 "failed with $?"; exit 1; }

        cd "$tmp" || exit

        if [ -z "$newtag" ]; then # If newtag is empty then get the latest release
            newtag=$(git tag | grep -v 'pre' | tail -1)
        fi
        if compareVersions "$currenttag" "$newtag"; then
            until [[ $ans == "yes" ]]; do
            echo "##  Upgrading to Version: $newtag from Version: $currenttag"
            echo
            echo -n "  Q. Would you like to continue? (y/n) "
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

            if [ -d "$backup" ]; then #if dir does exist
                echo "##  Backup directory already exists, using it."
                echo "    $backup"
            else
                echo "##  Setting up backup directory."
                echo "    $backup"
                mkdir -p "$backup"
            fi

            echo "##  Backing up app file."
            cp "$webdir"/app/config/app.php "$backup"

            echo "##  Backing up $si folder."
            cp -R "$webdir" "$backup"/"$name"
            rm -rf "${webdir:?}"

            echo "##  Backing up database."
            mysqldump "$name" > "$backup"/"$name".sql

            echo -n "##  Downloading Snipe-IT from github and put it in the web directory...";
            git clone -q https://github.com/"$fork"/snipe-it "$webdir" || { echo >&2 "failed with $?"; exit 1; }

            # get latest stable release
            cd "$webdir" || exit
            if [ -z "$newtag" ]; then
                newtag=$(git tag | grep -v 'pre' | tail -1)
            fi

            echo "  -- Installing version: $newtag"
            git checkout -b "$newtag" "$newtag" >> "$log" 2>&1

            echo "##  Restoring files."
            echo "  -- Restoring app config file."
            if [ -e "$backup"/app.php ]; then
                cp "$backup"/app.php "$webdir"/app/config/
            fi
            echo "  -- Restoring app production file."
            if [ -e "$backup"/"$name"/app/config/production/app.php ]; then
                cp "$backup"/"$name"/app/config/production/app.php "$webdir"/app/config/production/
            fi
            echo "  -- Restoring bootstrap file."
            if [ -e "$backup"/"$name"/bootstrap/start.php ]; then
                cp "$backup"/"$name"/bootstrap/start.php "$webdir"/bootstrap/
            fi
            echo "  -- Restoring database file."
            if [ -e "$backup"/"$name"/app/config/production/database.php ]; then
                cp "$backup"/"$name"/app/config/production/database.php "$webdir"/app/config/production/
            fi
            echo "  -- Restoring mail file."
            if [ -e "$backup"/"$name"/app/config/production/mail.php ]; then
                cp "$backup"/"$name"/app/config/production/mail.php "$webdir"/app/config/production/
            fi
            if compareVersions "$currenttag" 2.1.0; then
                echo "  -- Restoring ldap file."
                if [ -e "$backup"/"$name"/app/config/production/ldap.php ]; then
                    cp "$backup"/"$name"/app/config/production/ldap.php "$webdir"/app/config/production/
                fi
            fi
            echo "  -- Restoring composer files."
            if [ -e "$backup"/"$name"/composer.phar ]; then
                cp "$backup"/"$name"/composer.phar "$webdir"
            fi
            if [ -d "$backup"/"$name"/vendor ]; then
                cp -r "$backup"/"$name"/vendor "$webdir"
            fi
        else
            echo
            echo -e "\e[31m    You are already on the latest version.\e[0m"
            echo -e "\e[33m    Version: $currenttag\e[0m"
            echo
            exit
        fi
    fi
        # Change permissions on directories
        setupPermissions
        askDebug

        echo "##  Running composer to apply update."
        echo
        php composer.phar install --no-dev --prefer-source
        php composer.phar dump-autoload
        php artisan migrate

        echo "Upgraded $si to version:$newtag from:$currenttag" >> "$log" 2>&1

        echo
        echo -e "\e[33m    You are now on Version $newtag of $si.\e[0m"
        exit
else
    echo -e "\e[31m  ## No previous version of $si found.\e[0m"
fi
