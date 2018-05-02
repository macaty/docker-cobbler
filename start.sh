#!/bin/bash

set -ex

if [ ! $SERVER_IP ]
then
        echo "Please use $SERVER_IP to set the cobbler server IP address."
        exit 1
elif [ ! $SERVER_PORT ]
then
        echo "Please use $SERVER_PORT to set the cobbler server port."
elif [ ! $DHCP_RANGE ]
then
        echo "Please use $DHCP_RANGE set up DHCP network segment."
        exit 1
elif [ ! $ROOT_PASSWORD ]
then
        echo "Please use $ROOT_PASSWORD set the root password."
        exit 1
elif [ ! $DHCP_SUBNET ]
then
        echo "Please use $DHCP_SUBNET set the dhcp subnet."
        exit 1
elif [ ! $DHCP_MASK ]
then
        echo "Please use $DHCP_MASK set the dhcp mask."
        exit 1
elif [ ! $DHCP_ROUTER ]
then
        echo "Please use $DHCP_ROUTER set the dhcp router."
        exit 1
elif [ ! $DHCP_DNS ]
then
        echo "Please use $DHCP_DNS set the dhcp dns."
        exit 1
else
        PASSWORD=`openssl passwd -1 -salt hLGoLIZR $ROOT_PASSWORD`
        sed -i "s/^server: 127.0.0.1/server: $SERVER_IP/g" /etc/cobbler/settings
        sed -i "s/^next_server: 127.0.0.1/next_server: $SERVER_IP/g" /etc/cobbler/settings
        sed -i 's/pxe_just_once: 0/pxe_just_once: 1/g' /etc/cobbler/settings
        sed -i 's/manage_dhcp: 0/manage_dhcp: 1/g' /etc/cobbler/settings
        sed -i "s/http_port: 80/http_port: $SERVER_PORT/g" /etc/cobbler/settings
        sed -i "s#^default_password.*#default_password_crypted: \"$PASSWORD\"#g" /etc/cobbler/settings
        sed -i "s/192.168.1.0/$DHCP_SUBNET/" /etc/cobbler/dhcp.template
        sed -i "s/255.255.255.0/$DHCP_MASK/g" /etc/cobbler/dhcp.template
        sed -i "s/192.168.1.5/$DHCP_ROUTER/" /etc/cobbler/dhcp.template
        sed -i "s/192.168.1.1;/$DHCP_DNS;/" /etc/cobbler/dhcp.template
        sed -i "s/192.168.1.100 192.168.1.254/$DHCP_RANGE/" /etc/cobbler/dhcp.template
        sed -i "s/^Listen 80/Listen $SERVER_PORT/" /etc/httpd/conf/httpd.conf
        sed -i "s/^#ServerName www.example.com:80/ServerName localhost:$SERVER_PORT/" /etc/httpd/conf/httpd.conf
        sed -i "s/service %s restart/supervisorctl restart %s/g" /usr/lib/python2.7/site-packages/cobbler/modules/sync_post_restart_services.py

        digest="$( printf "%s:%s:%s" "$COBBLER_WEB_USER" "Cobbler" "$COBBLER_WEB_PASS" | 
                   md5sum | awk '{print $1}' )"
        printf "%s:%s:%s\n" "$COBBLER_WEB_USER" "Cobbler" "$digest" > "/etc/cobbler/users.digest"

        rm -rf /run/httpd/*
        /usr/sbin/apachectl
        /usr/bin/cobblerd

#        cobbler get-loaders
        cobbler sync

        pkill cobblerd
        pkill httpd
        rm -rf /run/httpd/*
        
        exec supervisord -n -c /etc/supervisord.conf
fi
