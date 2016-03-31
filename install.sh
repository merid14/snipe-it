# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi
wget https://raw.githubusercontent.com/snipe/snipe-it/master/install/snipeit.sh
chmod 744 snipeit.sh
sudo ./install/snipeit.sh 2>&1 | sudo tee -a /var/log/snipeit-install.log
