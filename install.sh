# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi
#  Set this to your github username and branch to pull your changes ** Only for Devs **
fork="snipe"
branch="master"

link="https://raw.githubusercontent.com/$fork/snipe-it/$branch/install/"
tmp=/tmp/snipeit/
tmpinstall=/tmp/snipeit/install/
log="/var/log/snipeit-install.log"

rm -rf "${$tmp:?}"
mkdir -p "$tmpinstall"

wget "$link"/snipeit.sh -P "$tmpinstall"
wget "$link"/upgrade.sh -P "$tmpinstall"
wget "$link"/functions.sh -P "$tmpinstall"

chmod -R 744 "$tmpinstall"
. "$tmpinstall"/snipeit.sh 2>&1 | sudo tee -a /var/log/snipeit-install.log
