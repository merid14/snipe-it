#!/bin/bash
# shellcheck disable=SC2154,SC2034
# -----------------------------------------------------------------------------
#   Snipe-It Installer
#   Mike Tucker | mtucker6784@gmail.com
#   Walter Wahlstedt | merid14@gmail.com
#
#   This installer is for Debian and CentOS based distributions.
#   We assume you will be installing as a subdomain on a fresh OS install.
#   Mail is setup separately. SELinux is assumed to be disabled.
#
#   NOTICE: If you would like to see whats going on in the background
#           while running the script please open a new shell and run:
#
#                   tail -f /var/log/snipeit-install.log
#
# -----------------------------------------------------------------------------
set -o nounset errexit pipefail

# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi


#  Set this to your github username and branch to pull your changes ** Only for Devs **
#  Leave tag="" for latest release.
fork="snipe"
branch="master"
tag=""
method="git"

while [[ "$@" > 1 ]]
do
# process arguments
arg="$1"
    case "$arg" in
        -h|"--help" )
            echo "";
            echo "  Usage: ./installfog.sh [options]";
            echo "       Options:";
            echo "             -h or --help         Displays this message";
            echo "             -f or --fork         Set the fork to pull from";
            echo "             -b or --branch       Set the branch to pull from";
            echo "             -t or --tag          Set the tag to pull from";
            echo "             -T or --get-tags     List and set the tag to pull from";
            echo "             --file-copy          Set the install method to file copy";
            echo "";
            echo "             To follow the log while running this script open new shell";
            echo "             and execute 'tail -f /var/log/snipeit-install.log'";
#           echo "                                  from previous version.";
#           echo "             --uninstall         Not yet supported";
#           echo "             --no-htmldoc        Don't try to install htmldoc";
#           echo "                                 (You won't be able to create pdf reports)";
            echo "";
            exit 1;
            ;;
        -f|"--fork" )
            fork="$2"
            shift # past argument=value
            echo "Fork  = $fork"
            ;;
        -b|"--branch" )
            branch="$2"
            shift # past argument=value
            echo "Branch  = $branch"
            ;;
        -t|"--tag" )
            tag="$2"
            shift # past argument=value
            echo "Tag  = $tag"
            ;;
        -T|"--git-tags" )
            if git --git-dir=/var/www/html/snipeit/.git/ tag;then echo
                tags="$(git --git-dir=/var/www/html/snipeit/.git/ tag)"
            elif git --git-dir=/var/www/snipeit/.git/ tag;then echo
                tags="$(git --git-dir=/var/www/snipeit/.git/ tag)"
            fi
                echo "Enter tag:"
                read tag
                if git --git-dir=/var/www/html/snipeit/.git/ tag --contains $tag > /dev/null 2>&1;then
                    echo "tag found using $tag"
                elif git --git-dir=/var/www//snipeit/.git/ tag --contains $tag > /dev/null 2>&1;then
                    echo "tag found using $tag"
                else
                        echo "$tag not found. Using latest stable tag."
                        tag=""
                fi
            shift # past argument=value
            ;;
        "--file-copy" )
            file="v"$branch".zip"
            method="fc"
            shift # past argument=value
            echo "Using file-copy method"
            ;;
    esac
    shift # past argument or value
done

link="https://raw.githubusercontent.com/$fork/snipe-it/$branch/install/"
tmp=/tmp/snipeit/
tmpinstall=/tmp/snipe-it/install/
log="/var/log/snipeit-install.log"

rm -rf "${tmp:?}"
rm -rf "${tmpinstall:?}"

mkdir -p "$tmp"
mkdir -p "$tmpinstall"

wget "$link"/snipeit.sh -P "$tmpinstall" 2>&1 | grep -i "failed\|error"
wget "$link"/upgrade.sh -P "$tmpinstall" 2>&1 | grep -i "failed\|error"
wget "$link"/functions.sh -P "$tmpinstall" 2>&1 | grep -i "failed\|error"
if [ ! -e "$tmpinstall/snipeit.sh" ] && [ ! -e "$tmpinstall/upgrade.sh" ] && [ ! -e "$tmpinstall/functions.sh" ];then
    echo "Failed to download install files."
    exit
fi

echo "  Press enter to continue."
read test

chmod -R 755 "$tmpinstall"
. "$tmpinstall"/snipeit.sh 2>&1 | sudo tee -a /var/log/snipeit-install.log
