#!/bin/bash

################################################################################
##          Installation script for Plesk                                     ##
################################################################################

# Edit variables for Plesk pre-configuration
#Install dialog program to show cli-gui elements
yum install dialog -y
#Set locale for putty to work properly with dialog
export NCURSES_NO_UTF8_ACS=1
#Update managed_support user and add to sudoers group
if [ $(id -u) -eq 0 ]; then
	#read -p "Enter username : " username
	read -s -p "Enter password for managed_support user : " password 
	echo -e "\e[32mMake sure you save this in WHMCS\e[0m"
	egrep "^managed_support" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo "managed_support exists!"
		exit 1
	else
		#pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
		useradd -m -p "$pass" "managed_support"
		[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
		#add managed_support user to sudoers
		usermod -aG wheel managed_support
	fi
else
	echo "Only root may add a user to the system."
	exit 2
fi
echo "Update ROOT user password"
passwd
echo "Waiting for 15 seconds to continue"
sleep 15

#email='admin@test.tst'
#passwd='CookBook123'
#name='admin'
agreement=true

# OS Selection, selecting an OS to determine what to install
HEIGHT=0
WIDTH=50
CHOICE_HEIGHT=0
BACKTITLE="Linux Provisioning Script"
TITLE="OS Selection"
MENU="Choose one of the following options:"

OPTIONS=(1 "REHL/CentOS/AlmaLinux"
         2 "Ubuntu LTS")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
        1)
            echo -e "\e[32mYou chose REHL/CentOS/AlmaLinux\e[0m"
			yum update -y
			yum install wget -y
			yum install nano -y
            ;;
        2)
            echo "\e[32mYou chose Ubuntu LTS\e[0m"
			apt-get -y update
			apt-get -y install wget
			apt-get -y install nano
            ;;
esac

# Plesk Variables
#P_HEIGHT=0
#P_WIDTH=75
#P_CHOICE_HEIGHT=0
#passwd=""
#name=""
#email=""

# open fd
#exec 3>&1

# Store data to $VALUES variable
#VALUES=$(dialog --ok-label "Submit" \
#	  --backtitle "Plesk Configuration" \
#	  --title "Plesk Information" \
#	  --form "Enter Plesk Information Below:" \
#		$P_HEIGHT $P_WIDTH $P_CHOICE_HEIGHT \
#	"E-Mail:" 1 1	"$email" 	1 10 30 0 \
#	"Plesk Password:"    2 1	"$passwd"  	2 10 30 0 \
#	"Customer Name/Business Name:"    3 1	"$name"  	3 10 30 0 \
#2>&1 1>&3)
#$randpw() {</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c16;}
passwd=$(</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c16;)
name=""
email=""
dialog --title "Plesk Information" --backtitle "Plesk Information" --ok-label "Submit" \
  --stdout --form "          (Use Arrow Keys To Go Between Fields)" 10 60 3 "Name:  " 1 1 "$name" 1 15 30 0 \
  "Password: " 2 1 "$passwd" 2 15 30 0 "E-mail:  " 3 1 "$email" 3 15 30 0 > output.txt
name=$(cat output.txt | head -1)
passwd=$(cat output.txt | head -2 | tail -1)
email=$(cat output.txt | head -3 | tail -1)

dialog --title "Confirm Values" --msgbox \
  "Confirm values for Plesk: \n Customer Name: $name \n Plesk Password: $passwd \n E-mail Address: $email " 0 0
# clear dialog just entered
clear
echo "Copy the Plesk password from the output below to WHMCS:"
cat output.txt
echo
echo "Sleeping for 30 seconds to continue so user can copy and paste Plesk password into WHMCS"
sleep 30
echo "The output.txt file will now be removed for security reasons"
rm output.txt

# Plesk Activation Code - provide proper license for initialization, it will be replaced after cloning
# leave as null if not providing key
activation_key=$1

# Plesk UI View - can be set to Service Provider View (spv) or Power User View (puv)
plesk_ui=spv

# Turn on Fail2Ban, yes or no, Keep in mind you need to provide temp license for initialization for this to work
fail2ban=yes

# Turn on http2
http2=yes

# Turn on Cloning - Set to "on" if this it to make a Golden Image, set to "off" if for remote installation
clone=off

# Test to make sure all initialization values are set

if [[ -z $activation_key ]]; then
echo 'Please provide a proper Plesk Activation Code (Bundle License).'
  exit 1
fi

if [[ -z $email || -z $passwd || -z $name || -z $agreement ]]; then
  echo 'One or more variables are undefined. Please check your initialization values.'
  exit 1
fi

echo "Plesk initialization values are all assigned. We are good so far."
echo

######### Do not edit below this line ###################
#########################################################

# Download Plesk AutoInstaller

echo "Downloading Plesk Auto-Installer"
wget https://installer.plesk.com/plesk-installer
echo

# Make Installed Executable

echo "Making Plesk Auto-Installer Executable"
chmod +x ./plesk-installer
echo

# Install Plesk with Required Components

echo "Starting Plesk Installation"
#./plesk-installer install plesk --preset Recommended --with fail2ban modsecurity psa-firewall pmm
./plesk-installer install plesk --preset Full --without git sitebuilder horde roundcube kav drweb spamassassin mailman postfix qmail msmtp dovecot courier ruby nodejs gems-pre advisor social-login domain-connect xovi composer monitoring
if [ $OUT -ne 0 ];then
  echo
  echo "An error occurred! The installation of Plesk failed. Please see logged lines above for error handling!"
  exit 1
fi

# If Ruby and NodeJS are needed then run install Plesk using the following command:
# ./plesk-installer install plesk --preset Recommended --with fail2ban modsecurity spamassassin mailman psa-firewall pmm health-monitor passenger ruby nodejs gems-preecho
echo
echo

# Initalize Plesk before Additional Configuration
# https://docs.plesk.com/en-US/onyx/cli-linux/using-command-line-utilities/init_conf-server-configuration.37843/

echo "Starting initialization process of your Plesk server"
plesk bin init_conf --init -email $email -passwd $passwd -name "$name" -license_agreed $agreement 

#plesk bin settings --set solution_type="wordpress"
echo

# Install Plesk Activation Key if provided
# https://docs.plesk.com/en-US/onyx/cli-linux/using-command-line-utilities/license-license-keys.71029/

if [[ -n "$activation_key" ]]; then
  echo "Installing Plesk Activation Code"
  plesk bin license --install $activation_key
  echo
fi

# Configure Service Provider View On

if [ "$plesk_ui" = "spv" ]; then
    echo "Setting to Service Provider View"
    plesk bin poweruser --off
    echo
else
    echo "Setting to Power user View"
    plesk bin poweruser --on
    echo
fi
#Remove Default Plesk Service Plans
plesk bin service_plan -r "Default Domain"
plesk bin service_plan -r "Default Simple"
plesk bin reseller_plan -r "Default Reseller"

# Make sure Plesk UI and Plesk Update ports are allowed

echo "Setting Firewall to allow proper ports"
iptables -I INPUT -p tcp --dport 21 -j ACCEPT
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
iptables -I INPUT -p tcp --dport 25 -j ACCEPT
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 110 -j ACCEPT
iptables -I INPUT -p tcp --dport 143 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 465 -j ACCEPT
iptables -I INPUT -p tcp --dport 993 -j ACCEPT
iptables -I INPUT -p tcp --dport 995 -j ACCEPT
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
iptables -I INPUT -p tcp --dport 8447 -j ACCEPT
iptables -I INPUT -p tcp --dport 8880 -j ACCEPT
iptables -A INPUT -p tcp --match multiport --dports 1024:1050 -j ACCEPT
echo

# Enable Modsecurity
# https://docs.plesk.com/en-US/onyx/administrator-guide/server-administration/web-application-firewall-modsecurity.73383/

#echo "Turning on Modsecurity WAF Rules"
#plesk bin server_pref --update-web-app-firewall -waf-rule-engine on -waf-rule-set tortix -waf-rule-set-update-period daily -waf-config-preset tradeoff
#echo

# Enable Fail2Ban and Jails
# https://docs.plesk.com/en-US/onyx/cli-linux/using-command-line-utilities/ip_ban-ip-address-banning-fail2ban.73594/

if [ "$fail2ban" = "yes" ]; then
  echo "Configuring Fail2Ban and its Jails"
  plesk bin ip_ban --enable
  plesk bin ip_ban --enable-jails ssh
  plesk bin ip_ban --enable-jails recidive
  plesk bin ip_ban --enable-jails modsecurity
  plesk bin ip_ban --enable-jails plesk-proftpd
  plesk bin ip_ban --enable-jails plesk-postfix
  plesk bin ip_ban --enable-jails plesk-dovecot
  plesk bin ip_ban --enable-jails plesk-roundcube
  plesk bin ip_ban --enable-jails plesk-apache-badbot
  plesk bin ip_ban --enable-jails plesk-panel
  plesk bin ip_ban --enable-jails plesk-wordpress
  plesk bin ip_ban --enable-jails plesk-apache
  plesk bin ip_ban --enable-jails plesk-horde
  echo
fi

# Turn on http2
# https://docs.plesk.com/en-US/onyx/administrator-guide/web-servers/apache-and-nginx-web-servers-linux/http2-support-in-plesk.76461/

if [ "$http2" = "yes" ]; then
  echo "Activating http2"
  /usr/sbin/plesk bin http2_pref --enable
  echo
fi

# Install Bundle Extensions
# https://docs.plesk.com/en-US/onyx/cli-linux/using-command-line-utilities/extension-extensions.71031/

#echo "Installing Requested Plesk Extensions"
#echo
#echo "Installing SEO Toolkit"
#plesk bin extension --install-url https://ext.plesk.com/packages/2ae9cd0b-bc5c-4464-a12d-bd882c651392-xovi/download
#echo
#echo "Installing BoldGrid"
#plesk bin extension --install-url https://ext.plesk.com/packages/e4736f87-ba7e-4601-a403-7c82682ef07d-boldgrid/download
#echo
#echo "Installing Backup to Cloud extensions"
#plesk bin extension --install-url https://ext.plesk.com/packages/9f3b75b3-d04d-44fe-a8fa-7e2b1635c2e1-dropbox-backup/download
#plesk bin extension --install-url https://ext.plesk.com/packages/52fd6315-22a4-48b8-959d-b2f1fd737d11-google-drive-backup/download
#plesk bin extension --install-url https://ext.plesk.com/packages/8762049b-870e-47cb-ba14-9f055b99b508-s3-backup/download
#plesk bin extension --install-url https://ext.plesk.com/packages/a8e5ad9c-a254-4bcf-8ae4-5440f13a88ad-one-drive-backup/download
#echo
#echo "Installing Speed Kit"
#plesk bin extension --install-url https://ext.plesk.com/packages/11e1bf5f-a0df-48c6-8761-e890ff4e906c-baqend/download
#echo
#echo "Installing ImunifyAV"
#plesk bin extension --install-url https://ext.plesk.com/packages/b71916cf-614e-4b11-9644-a5fe82060aaf-revisium-antivirus/download
#echo
#echo "Installing Google Pagespeed Insights"
#plesk bin extension --install-url https://ext.plesk.com/packages/3d2639e6-64a9-43fe-a990-c873b6b3ec66-pagespeed-insights/download
#echo
#echo "Installing Uptime Robot"
#plesk bin extension --install-url https://ext.plesk.com/packages/7d37cfde-f133-4085-91ea-d5399862321b-uptime-robot/download
#echo
#echo "Installing Sucuri Site Scanner"
#plesk bin extension --install-url https://ext.plesk.com/packages/2d5b423b-9104-40f2-9286-a75a6debd43f-sucuri-scanner/download
#echo 
#echo "Installing Domain Connect"
#plesk bin extension --install-url https://ext.plesk.com/packages/3a36f828-e477-4600-be33-48c21e351c9a-domain-connect/download
#echo
#echo "Installing Welcome Guide"
#plesk bin extension --install-url https://ext.plesk.com/packages/39eb8f3d-0d9a-4605-a42a-c37ca5809415-welcome/download
#echo
#echo "Enabling Welcome Guide for the Plesk WordPress Edition"
#plesk ext welcome --select -preset wordpress
#echo 

# Prepair for Cloning
# https://docs.plesk.com/en-US/onyx/cli-linux/using-command-line-utilities/cloning-server-cloning-settings.71035/

if [ "$clone" = "on" ]; then
	echo "Setting Plesk Cloning feature."
	plesk bin cloning --update -prepare-public-image true -reset-lincese true -skip-update true
	echo "Plesk initialization will be wiped on next boot. Ready for Cloning."
else
  echo "Here is your login"
  plesk login
fi

echo "Creating PASSIVE FTP config file for ProFTPD:"
touch /etc/proftpd.d/55-passive-ports.conf
echo
echo "Your Plesk Install is complete"
echo
echo "Use the following KB to update PASSIVE FTP to 1024-1050 for PROFTPD: https://docs.plesk.com/en-US/obsidian/administrator-guide/server-administration/plesk-for-linux-configuring-passive-ftp-mode.74643/"
nano /etc/proftpd.d/55-passive-ports.conf
echo
#This function will remove the script file once complete for cleanup
rm -- "$0"