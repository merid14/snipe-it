#  This is a script to upgrade snipeit
#  Written by: Walter Wahlstedt

# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi

clear
#  Set this to your github username to pull your changes ** Only for Devs **
fork='snipe'
#  Set this to the branch you want to pull  ** Only for Devs **
branch='develop'

##TODO: Update docs on what the upgrade script is doing

name='snipeit'
si="Snipe-IT"
date="$(date '+%Y-%b-%d')"
backup=/opt/$name/backup/$date
webdir=/var/www/html
installed="$webdir/$name/.installed"
log="$(find /var/log/ -type f -name "snipeit-install.log")"

echo "##  Checking for previous version of $si."
echo ""


##TODO: Check if /var/log/snipeit-install.log exists. if it does suggest upgrade path.
##TODO: Add .snipeitinstaller with app version

if [$log]
then
    echo "##  $name install found."
    echo "    Proceeding with upgrade."
    echo >> $installed "updated to $si version: from:"
else
fi


echo "##  Beginning the snipeit update process."
echo ""

echo "##  Setting up backup directory."
echo "    $backup"
mkdir $backup

##TODO: Backup app/config/app.php file /opt/snipeit/backup/$date
##TODO: Backup database to /opt/snipeit/backup/$date
##TODO: Empty these directories: app/storage/cache and app/storage/views

echo "Getting update."
echo ""

#TODO: Write warning that we are pulling from master not the latest release.
    #TODO: Pull from latest release with: git tag | grep -v 'pre' | tail -1

until [[ $ans == "yes" ]]; do
setbranch=1
echo "  Q. What branch would you like to use to upgrade? (latest release) "
echo ""
echo "    1. Latest Release (default)"
echo "    2. Master"
echo "    3. Develop"
echo ""
read setbranch
echo " setbranch equals $setbranch."
case $setbranch in
        1)
              echo "  Branch has been set to latest release."

                branch=$(git tag | grep -v 'pre' | tail -1)
                ans="yes"
                ;;
        2)
              echo "  Branch has been set to master."
                branch="master"
                ans="yes"
                ;;
        3)
                echo "  Branch has been set to develop."
                branch="develop"
                ans="yes"
                ;;
        *)        echo "  Invalid answer. Please select the number for the branch you want."
                ;;
esac
done
file=$branch'.zip'

# echo "Applying update files."
##TODO: Copy app/config/app.php back


echo "##  Running composer to apply update."
echo ""
sudo php composer.phar install --no-dev --prefer-source
sudo php composer.phar dump-autoload
sudo php artisan migrate