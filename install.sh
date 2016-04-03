# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi

#  Set this to your github username and branch to pull your changes ** Only for Devs **
#  Leave branch="" for latest release.
fork="snipe"
branch="master"
tag=""

link="https://raw.githubusercontent.com/$fork/snipe-it/$branch/install/"
tmp=/tmp/snipeit/
tmpinstall=/tmp/snipe-it/install/
log="/var/log/snipeit-install.log"

rm -rf "${tmp:?}"
mkdir -p "$tmpinstall"

wget "$link"/snipeit.sh -P "$tmpinstall" 2>&1 | grep -i "failed\|error"
wget "$link"/upgrade.sh -P "$tmpinstall" 2>&1 | grep -i "failed\|error"
wget "$link"/functions.sh -P "$tmpinstall" 2>&1 | grep -i "failed\|error"
read test
chmod -R 755 "$tmpinstall"
. "$tmpinstall"/snipeit.sh 2>&1 | sudo tee -a /var/log/snipeit-install.log
