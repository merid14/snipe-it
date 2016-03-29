#!/bin/bash
# shellcheck disable=SC2086,SC2024
# ------------------------------------------------------------------
#	Snipe-It Install Script
#	Mike Tucker
#	mtucker6784@gmail.com
#
#	This script is just to help streamline the install
#	process for Debian and CentOS based distributions. I assume
#	you will be installing as a subdomain on a fresh OS install.
#	Right now I'm not going to worry about SMTP setup
#
# 	Feel free to modify, but please give
# 	credit where it's due. Thanks!
# ------------------------------------------------------------------

# ensure running as root
if [ "$(id -u)" != "0" ]; then
  exec sudo "$0" "$@"
fi
# Function Definition
#
function logvar()
# ------------------------------------------------------------------
#	Function Definition
#
#	Function takes Variable assigntment as argument
#		Executes the variable assignment then pulls out the variable
#		name and it's contents to put into the log file.
#
#	Example:
# 	logvar hostname="$(hostname)"
#
# ------------------------------------------------------------------
{
	eval "$1"
	var_name=$(echo "$1" | gawk -F'[=]+' ' {print $1}')
	var_cmd='$'$var_name
	eval echo "$var_name: $var_cmd"  >> "$log" 2>&1
}

clear
log="/var/log/snipeit-install.log"

echo "--------------  Collect info for log  -----------------" >> "$log" 2>&1
arch=$(uname -m)
kernel=$(uname -r)
if [ -f /etc/lsb-release ]; then
        os=$(lsb_release -s -d)
elif [ -f /etc/debian_version ]; then
        os="Debian $(cat /etc/debian_version)"
elif [ -f /etc/redhat-release ]; then
        os=$(cat /etc/redhat-release)
else
        os="$(uname -s) $(uname -r)"
fi

logvar os="OS: $os"
logvar arch="arch: $arch"
logvar kernel="kernel: $kernel"


#  Lets find what distro we are using and what version
logvar distro="$(cat /proc/version)"
if grep -q centos <<<"$distro"; then
	for f in $(find /etc -type f -maxdepth 1 \( ! -wholename /etc/os-release ! -wholename /etc/lsb-release -wholename /etc/\*release -o -wholename /etc/\*version \) 2> /dev/null);
	do
		distro="${f:5:${#f}-13}"
	done;
	if [ "$distro" = "centos" ] || [ "$distro" = "redhat" ]; then
		distro+="$(rpm -q --qf "%{VERSION}" "$(rpm -q --whatprovides redhat-release)")"
	fi
fi

echo "--------------  Declare Variables  -----------------" >> "$log" 2>&1
#  Set this to your github username to pull your changes ** Only for Devs **
logvar fork="snipe"
#  Set this to the branch you want to pull  ** Only for Devs **
logvar branch=""

case $os in
    *Ubuntu*)
		echo "  The installer has detected Ubuntu as the OS."
		distro=ubuntu
		webdir=/var/www
		apachefile=/etc/apache2/sites-available/$name.conf
		;;
    *Debian*)
		echo "  The installer has detected Debian as the OS."
		webdir=/var/www
		;;
    *centos6*|*redhat6*)
        echo "  The installer has detected $distro as the OS."
        distro=centos6
        webdir=/var/www/html
            ;;
    *centos7*|*redhat7*)
        echo "  The installer has detected $distro as the OS."
        distro=centos7
        webdir=/var/www/html
            ;;
    *)
        echo "  The installer has detected $distro as the OS."
        echo "  Unfortunately this installer doesn't work on your os."
        echo "  Please see snipeit docs for manual install: ."
        echo "      http://docs.snipeitapp.com/installation/downloading.html."
        exit
        ;;
esac

logvar name="snipeit"
logvar si="Snipe-IT"
logvar hostname="$(hostname)"
logvar fqdn="$(hostname --fqdn)"
logvar installed="$webdir/$name/.installed"
logvar ans=default
logvar hosts=/etc/hosts
logvar file=master.zip
logvar tmp=/tmp/"$name"
logvar todaysdate="$(date '+%Y-%b-%d')"
logvar backup=/opt/"$name"/backup/"$(date '+%Y-%b-%d')"



echo "--------------  Start Installer  -----------------" >> "$log" 2>&1

rm -rf "${$tmp:?}/"
mkdir "$tmp"

####################  Functions Go Here  ######################
function ShowProgressOf()
{
	tput civis
    "$@" >> "$log" 2>&1 &
    local pid=$!
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b\n"
    tput cnorm
}

function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}
####################    Functions End     ######################

echo "
	   _____       _                  __________
	  / ___/____  (_)___  ___        /  _/_  __/
	  \__ \/ __ \/ / __ \/ _ \______ / /  / /
	 ___/ / / / / / /_/ /  __/_____// /  / /
	/____/_/ /_/_/ .___/\___/     /___/ /_/
	            /_/
"

echo ""
echo ""
echo "  Welcome to Snipe-IT Inventory Installer for Centos and Debian!"
echo ""

case $distro in
        *Ubuntu*)
                echo "  The installer has detected Ubuntu as the OS."
                distro=ubuntu
                ;;
        *Debian*)
                echo "  The installer has detected Debian as the OS."
                distro=debian
                ;;
        *centos6*|*redhat6*)
                echo "  The installer has detected $distro as the OS."
                distro=centos6
                ;;
        *centos7*|*redhat7*)
                echo "  The installer has detected $distro as the OS."
                distro=centos7
                ;;
        *)
                echo "  The installer has detected $distro as the OS."
                echo "  Unfortunately this installer doesn't work on your os."
                echo "  Please see snipeit docs for manual install: ."
                echo "      http://docs.snipeitapp.com/installation/downloading.html."
                exit
                ;;
esac

########################   Begin installer questions   ########################
#Get your FQDN.
echo ""
echo -n "  Q. What is the FQDN of your server? ($fqdn): "
read -r fqdn
if [ -z "$fqdn" ]; then
        fqdn="$(hostname --fqdn)"
fi
echo "     Setting to $fqdn"
echo ""

#Do you want to set your own passwords, or have me generate random ones?
until [[ $ans == "yes" ]] || [[ $ans == "no" ]]; do
echo -n "  Q. Do you want to automatically create the snipe database user password? (y/n) "
read -r setpw

case $setpw in
        [yY] | [yY][Ee][Ss] )
                mysqluserpw="$(< /dev/urandom tr -dc _A-Za-z-0-9 | head -c16)"
                ans="yes"
                ;;
        [nN] | [n|N][O|o] )
                echo -n  "    Q. What do you want your snipeit user password to be?"
                read -sr mysqluserpw
                echo ""
				ans="no"
                ;;
        *) 		echo "    Invalid answer. Please type y or n"
                ;;
esac
done

#Snipe says we need a new 32bit key, so let's create one randomly and inject it into the file
random32="$(< /dev/urandom tr -dc _A-Za-z-0-9 | head -c32)"

dbsetup=$tmp/db_setup.sql
echo >> "$dbsetup" "CREATE DATABASE snipeit;"
echo >> "$dbsetup" "GRANT ALL PRIVILEGES ON snipeit.* TO snipeit@localhost IDENTIFIED BY '$mysqluserpw';"

chown root:root "$dbsetup"
chmod 700 "$dbsetup"

case $distro in
	debian)
		#####################################  Install for Debian ##############################################

		webdir=/var/www

		#Update/upgrade Debian repositories.
		echo ""
		echo "##  Updating Debian packages in the background. Please be patient."
		echo ""
		apachefile=/etc/apache2/sites-available/$name.conf

		export DEBIAN_FRONTEND=noninteractive
		apt-get update -q >> /var/log/snipeit-install.log 2>&1
		apt-get upgrade -q -y >> /var/log/snipeit-install.log 2>&1

		echo "##  Installing packages."
		echo "## Going to suppress more messages that you don't need to worry about. Please wait."
		apt-get install -q -y apache2 >> /var/log/snipeit-install.log 2>&1
		apt-get install -q -y git unzip php5 php5-mcrypt php5-curl php5-mysql php5-gd php5-ldap libapache2-mod-php5 curl debconf-utils >> /var/log/snipeit-install.log 2>&1

		apt-get install -q -y mariadb-server mariadb-client
		service apache2 restart

		#We already established MySQL root & user PWs, so we dont need to be prompted. Let's go ahead and install Apache, PHP and MySQL.
		echo "##  Setting up LAMP."
		#DEBIAN_FRONTEND=noninteractive apt-get install -y lamp-server^ >> /var/log/snipeit-install.log 2>&1

		#  Get files and extract to web dir
		echo ""
		echo "##  Downloading snipeit and extract to web directory."
		wget -P "$tmp"/ https://github.com/snipe/snipe-it/archive/"$file" >> /var/log/snipeit-install.log 2>&1
		unzip -qo "$tmp"/"$file" -d "$tmp"/
		cp -R "$tmp"/snipe-it-master "$webdir"/"$name"

		##  TODO make sure apache is set to start on boot and go ahead and start it

		#Enable mcrypt and rewrite
		echo "##  Enabling mcrypt and rewrite"
		php5enmod mcrypt >> /var/log/snipeit-install.log 2>&1
		a2enmod rewrite >> /var/log/snipeit-install.log 2>&1
		ls -al /etc/apache2/mods-enabled/rewrite.load >> /var/log/snipeit-install.log 2>&1

		#Create a new virtual host for Apache.
		echo "##  Create Virtual host for apache."
		echo >> $apachefile ""
		echo >> $apachefile ""
		echo >> $apachefile "<VirtualHost *:80>"
		echo >> $apachefile "ServerAdmin webmaster@localhost"
		echo >> $apachefile "    <Directory $webdir/$name/public>"
		echo >> $apachefile "        Require all granted"
		echo >> $apachefile "        AllowOverride All"
		echo >> $apachefile "   </Directory>"
		echo >> $apachefile "    DocumentRoot $webdir/$name/public"
		echo >> $apachefile "    ServerName $fqdn"
		echo >> $apachefile "        ErrorLog /var/log/apache2/snipeIT.error.log"
		echo >> $apachefile "        CustomLog /var/log/apache2/access.log combined"
		echo >> $apachefile "</VirtualHost>"

		## Merid14: I dont think this is necessary anymore
		# echo "##  Setting up hosts file."
		# echo >> $hosts "127.0.0.1 $hostname $fqdn"
		# a2ensite $name.conf >> /var/log/snipeit-install.log 2>&1

		#Modify the Snipe-It files necessary for a production environment.
		echo "##  Modify the Snipe-It files necessary for a production environment."
		echo "	Setting up Timezone."
		tzone=$(cat /etc/timezone);
		sed -i "s,UTC,$tzone,g" $webdir/$name/app/config/app.php

		echo "	Setting up bootstrap file."
		sed -i "s,www.yourserver.com,$hostname,g" $webdir/$name/bootstrap/start.php

		echo "	Setting up database file."
		cp $webdir/$name/app/config/production/database.example.php $webdir/$name/app/config/production/database.php
		sed -i "s,snipeit_laravel,snipeit,g" $webdir/$name/app/config/production/database.php
		sed -i "s,travis,snipeit,g" $webdir/$name/app/config/production/database.php
		sed -i "s,password'  => '',password'  => '$mysqluserpw',g" $webdir/$name/app/config/production/database.php

		echo "	Setting up app file."
		cp $webdir/$name/app/config/production/app.example.php $webdir/$name/app/config/production/app.php
		sed -i "s,production.yourserver.com,$fqdn,g" $webdir/$name/app/config/production/app.php
		sed -i "s,Change_this_key_or_snipe_will_get_ya,$random32,g" $webdir/$name/app/config/production/app.php
		## from mtucker6784: Is there a particular reason we want end users to have debug mode on with a fresh install?
		#sed -i "s,false,true,g" $webdir/$name/app/config/production/app.php

		echo "	Setting up mail file."
		cp $webdir/$name/app/config/production/mail.example.php $webdir/$name/app/config/production/mail.php

		##  TODO make sure mysql is set to start on boot and go ahead and start it

		#Change permissions on directories
		echo "##  Setting permissions on web directory."
		chmod -R 755 $webdir/$name/app/storage
		chmod -R 755 $webdir/$name/app/private_uploads
		chmod -R 755 $webdir/$name/public/uploads
		chown -R www-data:www-data /var/www/
		# echo "##  Finished permission changes."

		echo "##  Setting up your database."
		echo "##  Input your MySQL/MariaDB root password (blank if this is a fresh install): "
		echo ""
		mysql -u root -p < $dbsetup
		echo ""

		echo "##  Securing Mysql"
		echo "## I understand this is redundant. You don't need to change your root pw again if you don't want to."
		# Have user set own root password when securing install
		# and just set the snipeit database user at the beginning
		/usr/bin/mysql_secure_installation

		#Install / configure composer
		echo "##  Installing and configuring composer"
		curl -sS https://getcomposer.org/installer | php
		mv composer.phar /usr/local/bin/composer
		cd $webdir/$name/ || exit
		composer install --no-dev --prefer-source
		php artisan app:install --env=production

		echo "##  Restarting apache."
		service apache2 restart
		;;

	ubuntu)
		#####################################  Install for Ubuntu  ##############################################

		webdir=/var/www
		apachefile=/etc/apache2/sites-available/$name.conf
		export DEBIAN_FRONTEND=noninteractive
		#Update/upgrade Debian/Ubuntu repositories, get the latest version of git.
		echo ""
		echo -n "##  Updating ubuntu..."
		ShowProgressOf apt-get update

		echo -n "##  Upgrading ubuntu..."
		ShowProgressOf apt-get -y upgrade

		echo -n "##  Installing packages..."
		ShowProgressOf apt-get install -y git unzip php5 php5-mcrypt php5-curl php5-mysql php5-gd php5-ldap

		echo "##  Setting up LAMP."
		DEBIAN_FRONTEND=noninteractive apt-get install -y lamp-server^ >> "$log" 2>&1

		#  Get files and extract to web dir
		echo ""
		echo -n "##  Cloning Snipe-IT from github to the web directory...";
		ShowProgressOf git clone https://github.com/$fork/snipe-it $webdir/$name

		# get latest stable release
		cd $webdir/$name || exit
		if [ -z $branch ]; then
			branch=$(git tag | grep -v 'pre' | tail -1)
		fi
		echo "    Installing version: $branch"
		git checkout -b $branch $branch

##  TODO make sure apache is set to start on boot and go ahead and start it

		#Enable mcrypt and rewrite
		echo "##  Enabling mcrypt and rewrite"
		php5enmod mcrypt >> "$log" 2>&1
		a2enmod rewrite >> "$log" 2>&1
		ls -al /etc/apache2/mods-enabled/rewrite.load >> "$log" 2>&1

		if [ -f $apachefile ]; then
			echo "    VirtualHost already exists. $apachefile"
		else
			echo >> $apachefile ""
			echo >> $apachefile ""
			echo >> $apachefile "<VirtualHost *:80>"
			echo >> $apachefile "ServerAdmin webmaster@localhost"
			echo >> $apachefile "    <Directory $webdir/$name/public>"
			echo >> $apachefile "        Require all granted"
			echo >> $apachefile "        AllowOverride All"
			echo >> $apachefile "   </Directory>"
			echo >> $apachefile "    DocumentRoot $webdir/$name/public"
			echo >> $apachefile "    ServerName $fqdn"
			echo >> $apachefile "        ErrorLog /var/log/apache2/snipeIT.error.log"
			echo >> $apachefile "        CustomLog /var/log/apache2/access.log combined"
			echo >> $apachefile "</VirtualHost>"
		fi


		## Merid14: I dont think this is necessary anymore
		# echo "##  Setting up hosts file.";
		# if grep -q "127.0.0.1 $hostname $fqdn" "$hosts"; then
		# 	echo "    Hosts file already setup."
		# else
		# 	echo >> $hosts "127.0.0.1 $hostname $fqdn"
		# 	a2ensite $name.conf >> "$log" 2>&1
		# fi

		#Modify the Snipe-It files necessary for a production environment.
		echo "##  Modify the Snipe-It files necessary for a production environment."
		echo "	Setting up Timezone."
		tzone=$(cat /etc/timezone);
		sed -i "s,UTC,$tzone,g" $webdir/$name/app/config/app.php

		echo "	Setting up bootstrap file."
		sed -i "s,www.yourserver.com,$hostname,g" $webdir/$name/bootstrap/start.php

		echo "	Setting up database file."
		cp $webdir/$name/app/config/production/database.example.php $webdir/$name/app/config/production/database.php
		sed -i "s,snipeit_laravel,snipeit,g" $webdir/$name/app/config/production/database.php
		sed -i "s,travis,snipeit,g" $webdir/$name/app/config/production/database.php
		sed -i "s,password'  => '',password'  => '$mysqluserpw',g" $webdir/$name/app/config/production/database.php

		echo "	Setting up app file."
		cp $webdir/$name/app/config/production/app.example.php $webdir/$name/app/config/production/app.php
		sed -i "s,https://production.yourserver.com,http://$fqdn,g" $webdir/$name/app/config/production/app.php
		sed -i "s,Change_this_key_or_snipe_will_get_ya,$random32,g" $webdir/$name/app/config/production/app.php
		## from mtucker6784: Is there a particular reason we want end users to have debug mode on with a fresh install?
		#sed -i "s,false,true,g" $webdir/$name/app/config/production/app.php

		echo "	Setting up mail file."
		cp $webdir/$name/app/config/production/mail.example.php $webdir/$name/app/config/production/mail.php

##  TODO make sure mysql is set to start on boot and go ahead and start it

		echo "##  Setting up your database."
		echo "##  Input your MySQL/MariaDB root password (blank if this is a fresh install): "
		mysql -u root -p < $dbsetup

		echo "##  Securing Mysql."

		# Have user set own root password when securing install
		# and just set the snipeit database user at the beginning
		/usr/bin/mysql_secure_installation

		# Install / configure composer
		echo ""
		echo "##  Configuring composer."
		cd $webdir/$name || exit
		curl -sS https://getcomposer.org/installer | php
		php composer.phar install --no-dev --prefer-source

		#Change permissions on directories
		echo "##  Setting permissions on web directory."
		chmod -R 755 $webdir/$name/app/storage
		chmod -R 755 $webdir/$name/app/private_uploads
		chmod -R 755 $webdir/$name/public/uploads
		chown -R www-data:www-data /var/www/
		# echo "##  Finished permission changes."

		echo "##  Installing Snipe-IT."
		php artisan app:install --env=production

		echo "##  Restarting apache."
		service apache2 restart
		;;
	centos6 )
		#####################################  Install for Centos/Redhat 6  ##############################################

		webdir=/var/www/html

		#Allow us to get the mysql engine
		echo ""
		echo "##  Adding IUS, epel-release and mariaDB repos.";
		mariadbRepo=/etc/yum.repos.d/MariaDB.repo

		if [ -f "$mariadbRepo" ]; then
			echo "    Repo already exists. $apachefile"
		else
			touch $mariadbRepo
			echo >> $mariadbRepo "[mariadb]"
			echo >> $mariadbRepo "name = MariaDB"
			echo >> $mariadbRepo "baseurl = http://yum.mariadb.org/10.0/centos6-amd64"
			echo >> $mariadbRepo "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB"
			echo >> $mariadbRepo "gpgcheck=1"
			echo >> $mariadbRepo "enable=1"
		fi

		yum -y -q install wget epel-release >> "$log" 2>&1
		wget -P $tmp/ https://centos6.iuscommunity.org/ius-release.rpm >> "$log" 2>&1
		rpm -Uvh $tmp/ius-release*.rpm >> "$log" 2>&1


		#Install PHP and other needed stuff.
		echo "##  Installing PHP and other packages.";
		PACKAGES="httpd MariaDB-server git unzip php56u php56u-mysqlnd php56u-bcmath php56u-cli php56u-common php56u-embedded php56u-gd php56u-mbstring php56u-mcrypt php56u-ldap"

		for p in $PACKAGES;do
			if isinstalled $p; then
				echo " ##" $p "Installed"
			else
				echo -n " ##" $p "Installing... "
				yum -y -q install $p >> "$log" 2>&1
				echo "";
			fi
		done;

        echo ""
		echo -n "##  Cloning Snipe-IT from github to the web directory...";

		ShowProgressOf git clone https://github.com/$fork/snipe-it $webdir/$name
		# get latest stable release
		cd $webdir/$name || exit
		if [ -z $branch ]; then
			branch=$(git tag | grep -v 'pre' | tail -1)
		fi
		echo "    Installing version: $branch"
		git checkout -b $branch $branch

		# Make mariaDB start on boot and restart the daemon
		echo "##  Starting the mariaDB server.";
		chkconfig mysql on
		/sbin/service mysql start

		echo "##  Setting up your database."
		echo "##  Input your MySQL/MariaDB root password  (blank if this is a fresh install): "
		mysql -u root < $dbsetup

		echo "##  Securing mariaDB server.";
		/usr/bin/mysql_secure_installation

		#Create the new virtual host in Apache and enable rewrite

		echo "##  Creating the new virtual host in Apache.";
		apachefile=/etc/httpd/conf.d/$name.conf

		if [ -f "$apachefile" ]; then
		    echo ""
			echo "    VirtualHost already exists. $apachefile"
		else
			echo >> $apachefile ""
			echo >> $apachefile ""
			echo >> $apachefile "LoadModule rewrite_module modules/mod_rewrite.so"
			echo >> $apachefile ""
			echo >> $apachefile "<VirtualHost *:80>"
			echo >> $apachefile "ServerAdmin webmaster@localhost"
			echo >> $apachefile "    <Directory $webdir/$name/public>"
			echo >> $apachefile "        Allow From All"
			echo >> $apachefile "        AllowOverride All"
			echo >> $apachefile "        Options +Indexes"
			echo >> $apachefile "   </Directory>"
			echo >> $apachefile "    DocumentRoot $webdir/$name/public"
			echo >> $apachefile "    ServerName $fqdn"
			echo >> $apachefile "        ErrorLog /var/log/httpd/snipeIT.error.log"
			echo >> $apachefile "        CustomLog /var/log/access.log combined"
			echo >> $apachefile "</VirtualHost>"
		fi

		## Merid14: I dont think this is necessary anymore
		# echo ""
		# echo "##  Setting up hosts file.";
		# if grep -q "127.0.0.1 $hostname $fqdn" "$hosts"; then
		# 	echo "    Hosts file already setup."
		# else
		# 	echo >> $hosts "127.0.0.1 $hostname $fqdn"
		# fi


		# Make apache start on boot and restart the daemon
		echo "##  Starting the apache server.";
		chkconfig httpd on
		/sbin/service httpd start

		# Modify the Snipe-It files necessary for a production environment.
		echo "##  Modifying the Snipe-It files necessary for a production environment."
		echo "	Setting up Timezone."
		tzone=$(grep ZONE /etc/sysconfig/clock | tr -d '"' | sed 's/ZONE=//g');
		sed -i "s,UTC,$tzone,g" $webdir/$name/app/config/app.php

		echo "	Setting up bootstrap file."
		sed -i "s,www.yourserver.com,$hostname,g" $webdir/$name/bootstrap/start.php

		echo "	Setting up database file."
		cp $webdir/$name/app/config/production/database.example.php $webdir/$name/app/config/production/database.php
		sed -i "s,snipeit_laravel,snipeit,g" $webdir/$name/app/config/production/database.php
		sed -i "s,travis,snipeit,g" $webdir/$name/app/config/production/database.php
		sed -i "s,password'  => '',password'  => '$mysqluserpw',g" $webdir/$name/app/config/production/database.php

		echo "	Setting up app file."
		cp $webdir/$name/app/config/production/app.example.php $webdir/$name/app/config/production/app.php
		sed -i "s,https://production.yourserver.com,http://$fqdn,g" $webdir/$name/app/config/production/app.php
		sed -i "s,Change_this_key_or_snipe_will_get_ya,$random32,g" $webdir/$name/app/config/production/app.php
		## from mtucker6784: Is there a particular reason we want end users to have debug mode on with a fresh install?
		#sed -i "s,false,true,g" $webdir/$name/app/config/production/app.php

		echo "	Setting up mail file."
		cp $webdir/$name/app/config/production/mail.example.php $webdir/$name/app/config/production/mail.php

		# Install / configure composer
		echo "##  Configuring composer."
		cd $webdir/$name || exit
		curl -sS https://getcomposer.org/installer | php
		php composer.phar install --no-dev --prefer-source

		# Change permissions on directories
		echo "##  Setting permissions on web directory."
		chmod -R 755 $webdir/$name/app/storage
		chmod -R 755 $webdir/$name/app/private_uploads
		chmod -R 755 $webdir/$name/public/uploads
		chown -R apache:apache $webdir/$name

		echo "##  Installing Snipe-IT."
		php artisan app:install --env=production

#TODO detect if SELinux and firewall are enabled to decide what to do
		#Add SELinux and firewall exception/rules. Youll have to allow 443 if you want ssl connectivity.
		# chcon -R -h -t httpd_sys_script_rw_t $webdir/$name/
		# firewall-cmd --zone=public --add-port=80/tcp --permanent
		# firewall-cmd --reload


		echo "##  Restarting apache."
		service httpd restart
		;;
	centos7 )
		#####################################  Install for Centos/Redhat 7  ##############################################

		webdir=/var/www/html

		#Allow us to get the mysql engine
		echo ""
		echo "##  Add IUS, epel-release and mariaDB repos.";
		yum -y -q install wget epel-release >> "$log" 2>&1
		wget -P $tmp/ https://centos7.iuscommunity.org/ius-release.rpm >> "$log" 2>&1
		rpm -Uvh $tmp/ius-release*.rpm >> "$log" 2>&1

		#Install PHP and other needed stuff.
		echo "##  Installing PHP and other packages.";
		PACKAGES="httpd mariadb-server git unzip php56u php56u-mysqlnd php56u-bcmath php56u-cli php56u-common php56u-embedded php56u-gd php56u-mbstring php56u-mcrypt php56u-ldap"

		for p in $PACKAGES;do
			if isinstalled $p; then
				echo " ##" $p "Installed"
			else
				echo -n " ##" $p "Installing... "
				yum -y -q install $p >> "$log" 2>&1
			echo "";
			fi
		done;

        echo ""
		echo -n "##  Downloading Snipe-IT from github and put it in the web directory.";

		ShowProgressOf git clone https://github.com/$fork/snipe-it $webdir/$name
		# get latest stable release
		cd $webdir/$name || exit
		if [ -z $branch ]; then
			branch=$(git tag | grep -v 'pre' | tail -1)
		fi
		echo "    Installing version: $branch"
		git checkout -b $branch $branch

		# Make mariaDB start on boot and restart the daemon
		echo "##  Starting the mariaDB server.";
		systemctl enable mariadb.service
		systemctl start mariadb.service

		echo "##  Setting up your database."
		echo "##  Input your MySQL/MariaDB root password  (blank if this is a fresh install):"
		mysql -u root -p < $dbsetup

		echo "##  Securing mariaDB server.";
		echo "";
		echo "";
		/usr/bin/mysql_secure_installation

		#Create the new virtual host in Apache and enable rewrite
		apachefile=/etc/httpd/conf.d/$name.conf

		if [ $apachefile ]; then
			echo ""
			echo "    VirtualHost already exists. $apachefile"
		else
			echo >> $apachefile ""
			echo >> $apachefile ""
			echo >> $apachefile "LoadModule rewrite_module modules/mod_rewrite.so"
			echo >> $apachefile ""
			echo >> $apachefile "<VirtualHost *:80>"
			echo >> $apachefile "ServerAdmin webmaster@localhost"
			echo >> $apachefile "    <Directory $webdir/$name/public>"
			echo >> $apachefile "        Allow From All"
			echo >> $apachefile "        AllowOverride All"
			echo >> $apachefile "        Options +Indexes"
			echo >> $apachefile "   </Directory>"
			echo >> $apachefile "    DocumentRoot $webdir/$name/public"
			echo >> $apachefile "    ServerName $fqdn"
			echo >> $apachefile "        ErrorLog /var/log/httpd/snipeIT.error.log"
			echo >> $apachefile "        CustomLog /var/log/access.log combined"
			echo >> $apachefile "</VirtualHost>"
		fi

		## Merid14: I dont think this is necessary anymore
		# echo ""
		# echo "##  Setting up hosts file.";
		# if grep -q "127.0.0.1 $hostname $fqdn" "$hosts"; then
		# 	echo "    Hosts file already setup."
		# else
		# 	echo >> $hosts "127.0.0.1 $hostname $fqdn"
		# fi

		echo "##  Starting the apache server.";
		# Make apache start on boot and restart the daemon
		systemctl enable httpd.service
		systemctl restart httpd.service

		#Modify the Snipe-It files necessary for a production environment.
		echo "##  Modifying the Snipe-IT files necessary for a production environment."
		echo "	Setting up Timezone."
		tzone=$(timedatectl | gawk -F'[: ]+' ' $2 ~ /Timezone/ {print $3}');
		sed -i "s,UTC,$tzone,g" $webdir/$name/app/config/app.php

		echo "	Setting up bootstrap file."
		sed -i "s,www.yourserver.com,$hostname,g" $webdir/$name/bootstrap/start.php

		echo "	Setting up database file."
		cp $webdir/$name/app/config/production/database.example.php $webdir/$name/app/config/production/database.php
		sed -i "s,snipeit_laravel,snipeit,g" $webdir/$name/app/config/production/database.php
		sed -i "s,travis,snipeit,g" $webdir/$name/app/config/production/database.php
		sed -i "s,password'  => '',password'  => '$mysqluserpw',g" $webdir/$name/app/config/production/database.php

		echo "	Setting up app file."
		cp $webdir/$name/app/config/production/app.example.php $webdir/$name/app/config/production/app.php
		sed -i "s,https://production.yourserver.com,http://$fqdn,g" $webdir/$name/app/config/production/app.php
		sed -i "s,Change_this_key_or_snipe_will_get_ya,$random32,g" $webdir/$name/app/config/production/app.php
		sed -i "s,false,true,g" $webdir/$name/app/config/production/app.php

		echo "	Setting up mail file."
		cp $webdir/$name/app/config/production/mail.example.php $webdir/$name/app/config/production/mail.php

		# Install / configure composer
		echo "##  Configuring composer."
		cd $webdir/$name || exit
		curl -sS https://getcomposer.org/installer | php
		php composer.phar install --no-dev --prefer-source

		# Change permissions on directories
		echo "##  Setting permissions on web directory."
		chmod -R 755 $webdir/$name/app/storage
		chmod -R 755 $webdir/$name/app/private_uploads
		chmod -R 755 $webdir/$name/public/uploads
		chown -R apache:apache $webdir/$name

		echo "##  Installing Snipe-IT."
		php artisan app:install --env=production

#TODO detect if SELinux and firewall are enabled to decide what to do
		#Add SELinux and firewall exception/rules. Youll have to allow 443 if you want ssl connectivity.
		# chcon -R -h -t httpd_sys_script_rw_t $webdir/$name/
		# firewall-cmd --zone=public --add-port=80/tcp --permanent
		# firewall-cmd --reload

		echo "##  Restarting apache."
		systemctl restart httpd.service
		;;
esac

echo ""
echo "  ***If you want mail capabilities, open $webdir/$name/app/config/production/mail.php and fill out the attributes***"
echo ""
echo "  ***Open http://$fqdn to login to Snipe-IT.***"
echo ""
echo ""
echo "##  Cleaning up..."
echo >> $installed "Installed $si to version:$branch $date"
#rm -f snipeit.sh
#rm -f install.sh
rm -rf "${tmp:?}/"
echo "##  Done!"
sleep 1
