#!/bin/bash
echo "checking for root permissions..."

echo "setting flags..."

while getopts d:e:m:v:c: flag
do
    case "${flag}" in
    	d) domain=${OPTARG};;
        e) email=${OPTARG};;
        m) addmesh=${OPTARG};;
        v) addvpn=${OPTARG};;
        c) num_clients=${OPTARG};;
    esac
done

echo "checking for root permissions..."


if [ $EUID -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi




echo "checking dependencies..."

declare -A osInfo;
osInfo[/etc/debian_version]="apt-get install -y"u
osInfo[/etc/alpine-release]="apk --update add"
osInfo[/etc/centos-release]="yum install -y"
osInfo[/etc/fedora-release]="dnf install -y"

for f in ${!osInfo[@]}
do
    if [[ -f $f ]];then
        install_cmd=${osInfo[$f]}
    fi
done

if [ -f /etc/debian_version ]; then
	apt update
elif [ -f /etc/alpine-release ]; then
  apk update
elif [ -f /etc/centos-release ]; then
	yum update
elif [ -f /etc/fedora-release ]; then
	dnf update
fi

dependencies=( "docker.io" "docker-compose" "wireguard" "jq" )

for dependency in ${dependencies[@]}; do
    is_installed=$(dpkg-query -W --showformat='${Status}\n' ${dependency} | grep "install ok installed")

    if [ "${is_installed}" == "install ok installed" ]; then
        echo "    " ${dependency} is installed
    else
            echo "    " ${dependency} is not installed. Attempting install.
            ${install_cmd} ${dependency}
            sleep 5
            is_installed=$(dpkg-query -W --showformat='${Status}\n' ${dependency} | grep "install ok installed")
            if [ "${is_installed}" == "install ok installed" ]; then
                echo "    " ${dependency} is installed
            elif [ -x "$(command -v ${dependency})" ]; then
                echo "    " ${dependency} is installed
            else
                echo "    " failed to install ${dependency}. Exiting.
                exit 1
            fi
    fi
done

set -e

COREDNS_IP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
SERVER_PUBLIC_IP=$(curl -s ifconfig.me)
MASTER_KEY=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 30 ; echo '')

echo "   ----------------------------"
echo "                SETUP ARGUMENTS"
echo "   ----------------------------"
echo "    coredns ip: $COREDNS_IP"
echo "     public ip: $SERVER_PUBLIC_IP"
echo "    master key: $MASTER_KEY"
echo "   ----------------------------"

sleep 5

mkdir -p /etc/netmaker

wget -q -O /root/docker-compose.yml https://raw.githubusercontent.com/gravitl/netmaker/master/compose/docker-compose.yml
sed -i "s/SERVER_PUBLIC_IP/$SERVER_PUBLIC_IP/g" /root/docker-compose.yml
sed -i "s/COREDNS_IP/$COREDNS_IP/g" /root/docker-compose.yml
sed -i "s/REPLACE_MASTER_KEY/$MASTER_KEY/g" /root/docker-compose.yml

echo "starting containers..."

docker-compose -f /root/docker-compose.yml up -d

cat << "EOF"
    ______     ______     ______     __   __   __     ______   __                        
   /\  ___\   /\  == \   /\  __ \   /\ \ / /  /\ \   /\__  _\ /\ \                       
   \ \ \__ \  \ \  __<   \ \  __ \  \ \ \'/   \ \ \  \/_/\ \/ \ \ \____                  
    \ \_____\  \ \_\ \_\  \ \_\ \_\  \ \__|    \ \_\    \ \_\  \ \_____\                 
     \/_____/   \/_/ /_/   \/_/\/_/   \/_/      \/_/     \/_/   \/_____/                 
                                                                                         
 __   __     ______     ______   __    __     ______     __  __     ______     ______    
/\ "-.\ \   /\  ___\   /\__  _\ /\ "-./  \   /\  __ \   /\ \/ /    /\  ___\   /\  == \   
\ \ \-.  \  \ \  __\   \/_/\ \/ \ \ \-./\ \  \ \  __ \  \ \  _"-.  \ \  __\   \ \  __<   
 \ \_\\"\_\  \ \_____\    \ \_\  \ \_\ \ \_\  \ \_\ \_\  \ \_\ \_\  \ \_____\  \ \_\ \_\ 
  \/_/ \/_/   \/_____/     \/_/   \/_/  \/_/   \/_/\/_/   \/_/\/_/   \/_____/   \/_/ /_/ 
                                                                                         													 
EOF


echo "visit http://$SERVER_PUBLIC_IP to log in"
