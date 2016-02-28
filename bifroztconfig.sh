#!/bin/bash
#
#   Copyright (c) 2016, Are Hansen - Honeypot Development.
#
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without modification, are
#   permitted provided that the following conditions are met:
#
#   1. Redistributions of source code must retain the above copyright notice, this list
#   of conditions and the following disclaimer.
#
#   2. Redistributions in binary form must reproduce the above copyright notice, this
#   list of conditions and the following disclaimer in the documentation and/or other
#   materials provided with the distribution.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND AN
#   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
#   SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
#   INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
#   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
#   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
#   WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
declare -rx Script="${0##*/}"
declare rc_local="/etc/rc.local"
declare dhcpd_conf="/etc/dhcp/dhcpd.conf"
declare hs_active_cfg="/opt/honssh/honssh.cfg"
declare hs_default_cfg="/opt/honssh/honssh.cfg.default"
declare created="2016, Feb 27"
declare author="Are Hansen"
declare version="0.0.2-DEVELOPMENT-VERSION"


# Configuration start message.
function start_msg()
{
echo "
    !!! WARNING = SCRIPT NOT SUITABLE FOR PRODUCTION = WARNING !!!
    !!! WARNING = SCRIPT NOT SUITABLE FOR PRODUCTION = WARNING !!!
    !!! WARNING = SCRIPT NOT SUITABLE FOR PRODUCTION = WARNING !!!

    ========= $Script - $version - $created - $author =========

    You are about to configure some of the system object on this machine.

    The following information should be avalible to you before starting this process.
    - IPv4 address of both network interface cards on this machine.
    - What you are going to name this instance.
    - The MAC address from the honeypot.
    - Decide if HonSSH should be started at boot time or not.

    Your honeypot should be powered off while running this script.
    The script can be exited at any time by pressing CTRL + C.

    !!! WARNING = SCRIPT NOT SUITABLE FOR PRODUCTION = WARNING !!!
    !!! WARNING = SCRIPT NOT SUITABLE FOR PRODUCTION = WARNING !!!
    !!! WARNING = SCRIPT NOT SUITABLE FOR PRODUCTION = WARNING !!! 
"
}


# Searches dhcpd.conf and returns any item thats in the location of where the MAC address
# should be. The function is expected to return a numbered list of all MAC addresses in the
# /etc/dhcp/dhcpd.conf file.
function locate_current_mac()
{
    grep -B1 'fixed-address' "$dhcpd_conf" \
    | head -n1 \
    | awk '{ print $3 }' \
    | cut -d ';' -f1 \
    | cat -n
}


# Creates a copy of honssh.cfg.default and renames it into honssh.cfg, this is the
# configuration file that will be read when HonSSH starts up. If the honssh.cfg exists it
# will be renamed and a clean honssh.cfg file will be created. 
function make_cfg_active()
{
    if [ ! -e "$hs_default_cfg" ]
    then
        echo "FAILURE: Unable to locate $hs_default_cfg, please check if file is missing or paths in $Script"
        exit 1
    fi

    if [ -e "$hs_active_cfg" ]
    then
        hs_backup_cfg="$hs_active_cfg-$(date +"%y%m%d%H%M%S")"
        echo "Discovered an existing $hs_active_cfg, creating a backup called $hs_backup_cfg"
        mv "$hs_active_cfg" "$hs_backup_cfg" 
        echo "Creating clean $hs_active_cfg"
        cp "$hs_default_cfg" "$hs_active_cfg"
    fi

    if [ ! -e "$hs_active_cfg" ]
    then
        echo "Creating clean $hs_active_cfg"
        cp "$hs_default_cfg" "$hs_active_cfg"
    fi
}


# Configuration of HonSSH.
function configure_honssh()
{
    make_cfg_active

    echo -e "\n\n   ---------  HonSSH configuration ---------\n"

    echo "Enter the IPv4 address of eth0, if its dynamically assigned enter 0.0.0.0"
    while [ -z "$ip_eth0" ]
    do
        read -p "Enter IPv4 address of eth0: " ip_eth0
    done

    echo -e "\nEnter the IPv4 address of eth1, if you are using the default configuration it should be 192.168.27.1"
    while [ -z "$ip_eth1" ]
    do
        read -p "Enter IPv4 address of eth0: " ip_eth1
    done

    echo -e "\nEnter the IPv4 address of the honeypot, if you are using the default configuration it should be 192.168.27.200"
    while [ -z "$ip_honey" ]
    do
        read -p "Enter IPv4 address of the honeypot: " ip_honey
    done

    echo -e "\nSet a name for this instance (i.e. Bifrozt)"
    while [ -z "$sensor_name" ]
    do
        read -p "Instance name: " sensor_name
    done

    echo -e "\n\nHonSSH configuration summary\n"
    while [ -z "$confirm_hs" ]
    do
        echo "IPv4 address eth0: $ip_eth0"
        echo "IPv4 address eth1: $ip_eth1"
        echo "IPv4 address honeypot: $ip_honey"
        echo "Name of this instance: $sensor_name"
        echo -e "\nIs this correct? "
        while [ -z "$confirmed_hs" ]
        do
            read -p "Please answer YES or NO: " correct

            if [ "$correct_hs" = "YES" ]
            then
                confirmed_hs="$correct_hs"
                break
            else
                if [ "$correct_hs" = "NO" ]
                then
                    echo "Aborting configuration."
                    confirmed_hs="$correct_hs"
                    exit 1
                fi
            fi
        done
	confirm_hs="$correct"
    done

    echo -e "\nWriting configuration to $hs_active_cfg\n"
    # DEV NOTES: Check for config tag first
    sed -i "s/IP_eth0/$ip_eth0/g" "$hs_active_cfg"
    # DEV NOTES: Check for config tag first
    sed -i "s/IP_eth1/$ip_eth1/g" "$hs_active_cfg"
    # DEV NOTES: Check for config tag first
    sed -i "s/IP_HONEYPOT/$ip_honey/g" "$hs_active_cfg"
    # DEV NOTES: Check for config tag first
    sed -i "s/SENSOR_NAME/$sensor_name/g" "$hs_active_cfg"
}


# Configuration of the DHCP server.
function configure_dhcpd()
{
    echo -e "\n\n   ---------  DHCP server configuration ---------\n"

    echo "The DHCP server will make sure that the honeypot is always assigned the same IPv4 address."
    echo -e "The following MAC address(es) were found in the current configuration:\n"

    locate_current_mac

    echo -e "\nWhat MAC address should be replaced by the one on your honeypot?"    
    while [ -z "$replace_mac" ]
    do
        read -p "Enter MAC address (i.e. a0:b1:c2:d3:e4:f5:06): " replace_mac
    done

    echo -e "\nWhat is the MAC address of your honeypot?"
    while [ -z "$honey_mac" ]
    do
        read -p "Enter MAC address (i.e. 0a:1b:2c:3d:4e:5f:60): " honey_mac
    done

    echo -e "\n\nDHCP server configuration summary\n"
    while [ -z "$confirm_dhcp" ]
    do
        echo "Replace MAC address: $replace_mac"
        echo "With new MAC address: $honey_mac"        
        echo -e "\nIs this correct? "
        while [ -z "$confirmed_mac" ]
        do
            read -p "Please answer YES or NO: " correct_mac
            if [ "$correct_mac" = "YES" ]
            then
                confirmed_mac="$correct_mac"
                break
            else
                if [ "$correct_mac" = "NO" ]
                then
                    echo "Aborting configuration."
                    confirmed_mac="$correct_mac"
                    exit 1
                fi
            fi
        done
	confirm_dhcp="$correct_mac"
    done

    echo -e "\nWriting configuration to $dhcpd_conf\n"
    sed -i "s/$replace_mac/$replace_mac/g" "$dhcpd_conf"
}


# Configure autostart of HonSSH
function configure_autostart()
{
    echo -e "\nDo you want to start HonSSH automatically at boot?"
    while [ -z "$confirm" ]
    do
        while [ -z "$confirmed" ]
        do
            read -p "Please answer YES or NO: " correct
            if [ "$correct" = "YES" ]
            then
                break
            else
                if [ "$correct" = "NO" ]
                then
                    echo "Aborting configuration."
                    exit 1
                fi
            fi
        done
	confirm="$correct"
    done

    echo -e "\nWriting configuration to $dhcpd_conf\n"
    # DEV NOTES: Check for config tag first
    sed -i "s/#_#_#//g" "$rc_local"
}


# Configuration end message.
function end_msg()
{
echo '
    The configuration is now done, preform the following steps to complete it
    - Reboot this machine.
    - Start the honeypot
    - If NOT starting HonSSH at boot time, execute the following command on this machine
      sudo honsshctrl start
'
}


# Call all configuration functions.
function main()
{
    clear
    start_msg
    sleep 2
    configure_honssh
    configure_dhcpd
    configure_autostart
    end_msg
}


# Check for root.
if [ "$(id -u)" != "0" ]
then
    echo "FAILURE: $Script requires root privileges. Please try again with:"
    echo "sudo $Script"
    exit 1
fi


# Begin execution.
main


exit 0

