#!/bin/bash

if [[ $# == 1 ]]
then
    endpoint=$1
else
    enpoint="<unknown>"
fi


sudo apt install -y expect pwgen

#
# Install SoftEther VPN
#

vpncmd=$( realpath vpnserver/vpncmd )
vpnserver=$( realpath vpnserver/vpnserver )

if [[ ! -e $vpncmd || ! -e $vpnserver ]]
then

    ver="v4.41-9787-rtm-2023.03.14"

    case $( uname -m ) in
        "x86_64" )
            arch1="64bit_-_Intel_x64_or_AMD64"
            arch2="x64"
            ;;
        "aarch64" )
            arch1="64bit_-_ARM_64bit"
            arch2="arm64"
            ;;
        * )
            echo "Unknown arch: $( uname -m )"
            exit 1
            ;;
    esac

    tarball="softether-vpnserver.tar.gz"
    tarball_url="https://jp.softether-download.com/files/softether/${ver}-tree/Linux/SoftEther_VPN_Server/${arch1}/softether-vpnserver-${ver}-linux-${arch2}-64bit.tar.gz"
    curl $tarball_url -o $tarball
    tar -zxvf $tarball
    make -C vpnserver -j `nproc`
fi
vpncmd=$( realpath vpnserver/vpncmd )
vpnserver=$( realpath vpnserver/vpnserver )



#
# Initialize VPN
#

# Generate passwds
user="vpn"
server_passwd=$( pwgen -cnysB 8 1 | tee .server_passwd )
user_passwd=$( pwgen -cnysB 8 1 | tee .user_passwd )
presharedkey=$( pwgen -cnysB 8 1 | tee .presharedkey )

sudo $vpnserver stop
sudo pkill vpnserver
sudo sed -i -r "/^.+byte HashedPassword/d" vpnserver/vpn_server.config
sudo $vpnserver start
sleep 10


hub="default"
tap="tap-vpn"

# local bridge
ip link show $tap > /dev/null 2>&1
tap_exist=$( echo $? )
if [[ $tap_exist == 1 ]]
then
    sudo ip tuntap add dev $tap mode tap
    # sudo ip tuntap del dev $tap mode tap
fi
sudo ip link set dev $tap promisc on
sudo $vpncmd localhost /SERVER /CMD BridgeCreate $hub /DEVICE:$tap /TAP:yes

sudo $vpncmd localhost /SERVER /HUB:$hub /CMD UserCreate $user /GROUP:none /REALNAME:none /NOTE:none
sudo $vpncmd localhost /SERVER /HUB:$hub /CMD UserPasswordSet $user /PASSWORD:$user_passwd
sudo $vpncmd localhost /SERVER /HUB:$hub /CMD SecureNatEnable
sudo $vpncmd localhost /SERVER /CMD IPsecEnable /L2TP:yes /L2TPRAW:no /ETHERIP:no /PSK:$presharedkey /DEFAULTHUB:$hub
sudo $vpncmd localhost /SERVER /CMD ServerPasswordSet $server_passwd

ddns=$( sudo $vpncmd /SERVER localhost /PASSWORD:$server_passwd /CMD DynamicDnsGetStatus | grep -oE "\w+.softether.net" )

echo "L2TP Settings:"
echo "  Description:   Softether-vpn"
echo "  User Endpoint: $endpoint"
echo "  DDNS Endpoint: $ddns"
echo "  Account:       $user"
echo "  Password:      $user_passwd"
echo "  Secret:        $presharedkey"
echo "  Required NAT:  500/udp, 4500/udp"























