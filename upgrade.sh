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


##TODO: Check if /var/log/snipeit-install.log exists. if it does suggest upgrade path.
##TODO: Add .snipeitinstaller with app version

##TODO: Create backup directory /opt/snipeit/backup/$date
##TODO: Backup app/config/app.php file /opt/snipeit/backup/$date
##TODO: Backup database to /opt/snipeit/backup/$date
##TODO:
#  https://github.com/snipe/snipe-it/releases/latest
#  https://github.com/snipe/snipe-it/archive/v2.0.6.zip

until [[ $setbranch == "yes" ]] || [[ $ans == "no" ]]; do
echo -n "  Q. What branch would you like to use to upgrade? (master) "
read setbranch

case $setbranch in
        master)
				echo "  Branch has been set to master."
                branch="https://github.com/snipe/snipe-it/archive/master.zip"
                ans="yes"
                ;;
        develop)
                echo "  Branch has been set to develop."
                branch="https://github.com/snipe/snipe-it/archive/develop.zip"
                ;;
        *) 		echo "  Invalid answer. Please type y or n"
                ;;
esac
done
file=$branch'.zip'

name='snipeit'
webdir=/var/www/html
tmp=/tmp/$name

echo 'Beginning the snipeit update process.'
echo ""

echo 'Setting up temp directory.'
rm -rf $tmp
mkdir $tmp

echo "Getting update."

wget -P $tmp/ https://github.com/$fork/snipe-it/archive/$file >> /var/log/snipeit-update.log 2>&1

echo "Applying update files."

unzip -qo $tmp/$file -d $tmp/
cp -Ru $tmp/snipe-it-$branch/* $webdir/$name
cd /var/www/html/snipeit

echo "Running composer to apply update."
echo ""
sudo php composer.phar install --no-dev --prefer-source
sudo php composer.phar dump-autoload
sudo php artisan migrate