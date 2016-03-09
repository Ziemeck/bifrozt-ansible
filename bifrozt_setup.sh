#!/usr/bin/env bash
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
#   --------------------------------------------------------------
#
#   - 0.0.3-DEV
#     * Added change log data
#     * Removing the neccesity of using 'sudo su -' by generating the Ansible SSH key in a
#       custom location and setting the 'private_key_file' in ansible.cfg.
#     * Added 'info' argument.
#     * Supressed output from various commands.
#
#   - 0.0.4-DEV
#     * ´info´ argument has been removed.
#     * Dedicated function will now generate time stamps. 
#     * Replaced hardcoded items that were used multiple times with
#       declared variables
#     * Consolidated all scripted apt-get actions into a single function.
#     * Git clone function made re-usable.
#     * Function for getting IPv4 address from interfaces made re-usable.
#     * Random DHCP network generation during setup.
#     * Random IPv4 address for the honeypot generated during setup.
#     * Chooses a random empheral port for SSH administration.
#     * Updates firewall rules with new SSH port.
#     * Script now requires the MAC address of the honeypot as an argument.
#
#   - 0.0.5
#     * Makes HonSSH configuration active.
#
#   -------------------------------------------------------------- DEV NOTES
#
#   - if playbook exits with zero
#     - generate random rfc1918 network
#     - wget and run mhsc.sh
#     - run HonSSH setup
#     - set administrative SSH port
#     - reboot
#
set -e
declare -rx Script="${0##*/}"
declare honssh_dir="/opt/honssh"
declare git_bzans="https://github.com/Bifrozt/bifrozt-ansible.git"
declare hs_default_cfg="$honssh_dir/honssh.cfg.default"
declare hs_active_cfg="$honssh_dir/honssh.cfg"
declare ansible_cfg="/etc/ansible/ansible.cfg"
declare setup_log="/var/log/Bifrozt_Setup.log"
declare interfaces="/etc/network/interfaces"
declare ipv4_hater="/etc/network/ipv4hater"
declare dhcpd_conf="/etc/dhcp/dhcpd.conf"
declare sshd_conf="/etc/ssh/sshd_config"
declare dst_bzans="/tmp/bifrozt-ansible"
declare bz_key="/etc/ansible/BZKEY"
declare created="2016, Feb 24"
declare author="Are Hansen"
declare version="0.0.5"


# Nothing to see here, just a script banner.
function script_banner()
{
echo "

========= $Script - $version - $created - $author =========
"
}


# Time stamp.
# Return time stamp and information string.
# ARG 1: Information string.
function time_stamp()
{
    if [ ! -z "$1" ]
    then
        echo "$(date +"%Y-%m-%d %T") - $1"
    else
        echo "$FUNCNAME-ERROR: Received empty information string."
        exit 1
    fi
}


# Verify that the distro we are using is Ubuntu
function check_distro()
{
    lsb_release -a 2>/dev/null \
    | head -n1 \
    | awk '{ print $3 }'
}


# Verify that the host has two network interface cards. Expects them to start with 'eth'.
function check_if()
{
    ifconfig -a \
    | cut -c1-4 \
    | grep -c 'eth'
}


# Returns IPv4 address of interface.
# ARG 1: Interface name.
function ipv4_if()
{
    if [ ! -z "$1" ]
    then
        ifconfig "$1" \
        | grep 'inet addr:' \
        | cut -d ':' -f2 \
        | awk '{ print $1 }'
    else
        time_stamp "$FUNCNAME-ERROR: No argument received"
        exit 1
    fi
}


# Update system, add Ansible PPA, install ansible and configure Ansible host key checking.
function apt_get_things()
{
    time_stamp "Installing all avalible system updates..."
    apt-get update &>/dev/null
    apt-get upgrade -y &>/dev/null

    time_stamp "Installing some minor dependencies..."
    apt-get install software-properties-common git openssh-server -y &>/dev/null

    time_stamp "Adding Ansible PPA... "
    apt-add-repository ppa:ansible/ansible -y &>/dev/null

    time_stamp "Installing Ansible... "
    apt-get update &>/dev/null
    apt-get install ansible  -y &>/dev/null
    sed -i 's/#host_key_checking/host_key_checking/g' "$ansible_cfg"
}


# Clone git repo to destination.
# ARG 1: GitHub repo URL
# ARG 2: Local path
function git_clone()
{
    if [ -z "$1" ]
    then
        time_stamp "$FUNCNAME-ERROR: Did not receive any URL."
        exit 1
    fi

    if [ -z "$2" ]
    then
        time_stamp "$FUNCNAME-ERROR: Did not receive absoloute path to local destination."
        exit 1
    fi

    time_stamp "Grabbing a clone of $1..."
    git clone "$1" "$2" &>/dev/null
}


# Generate SSH keys for Ansible.
function gen_ssh_keys()
{
    if [ ! -d "$bz_key" ]
    then
        mkdir "$bz_key"
        chmod 0700 "$bz_key"
        chown root:root "$bz_key"
    fi

    time_stamp "Generating Ansible SSH keys..."
    ssh-keygen -f "$bz_key/id_rsa" -t rsa -N '' &>/dev/null

    if [ ! -e "$bz_key/id_rsa.pub" ]
    then
        time_stamp "FAIL: id_rsa.pub not found in expected location."
    	exit 1
    else
        time_stamp "Setting up authentication key for root user (will be removed later)..."
        cat "$bz_key/id_rsa.pub" > "/root/.ssh/authorized_keys"
    	chmod 0600 "$bz_key/id_rsa.pub"

        curr_str="#private_key_file = \/path\/to\/file"
        keys_str="private_key_file = \/etc\/ansible\/BZKEY\/id_rsa"
        sed -i "s/$curr_str/$keys_str/g" "$ansible_cfg"
    fi
}


# Takes two arguments to run a playbook.
# ARG 1: Absolute path to playbook.yml
# ARG 2: Absolute path to hosts file
function run_play()
{
    if [ -z "$1" ]
    then
        time_stamp "$FUNCNAME-ERROR: Did not receive absoloute path to playbook.yml"
        exit 1
    fi

    if [ ! -e "$1" ]
    then
        time_stamp "$FUNCNAME-ERROR: \"$1\" does not appear to exist."
        exit 1
    fi

    if [ -z "$2" ]
    then
        time_stamp "$FUNCNAME-ERROR: Did not receive absoloute path to playbook.yml"
        exit 1
    fi

    if [ ! -e "$2" ]
    then
        time_stamp "$FUNCNAME-ERROR: \"$2\" does not appear to exist."
        exit 1
    fi

    IPV4="$(ipv4_if eth0)"
    sed -i "s/IPv4_OR_FQDN/$IPV4/g" "$2"
    time_stamp "Executing the playbook now..."
    ansible-playbook "$1" -i "$2"
}


# Locates and retruns the current network name in the dhcpd.conf, excluding the last octet.
function locate_current_network()
{
    grep ^'subnet' "$dhcpd_conf" \
    | awk '{ print $2 }' \
    | cut -d '.' -f1-3
}


# Randomly generates a new network to be used by the DHCP server and returns on of the RFC1918 types.
function gen_new_network()
{
    echo -e "$RANDOM 10.$(jot -r 1 0 255).$(jot -r 1 0 255)\n$RANDOM 172.16.$(jot -r 1 0 255)\n$RANDOM 192.168.$(jot -r 1 0 255)" \
    | sort -n \
    | awk '{ print $2 }' \
    | head -n1
}


# Replace the default DHCP network with a randomly generated one, updates both the MAC address
# of the honeypot and honssh.cfg.default, after which it makes honssh.default.cfg into honssh.cfg.
# ARG 1: MAC address of honeypot. (This is validated and passed to this function from main.) 
function setup_dhcp()
{
    curr_net="$(locate_current_network)"
    new_net="$(gen_new_network)"

    if [ "$(ipv4_if eth0 | cut -d '.' -f1-3)" = "$new_net" ]
    then
        new_net="$(gen_new_network)"
    fi

    time_stamp "Assigning a randomized IPv4 address to the honeypot..."
    old_honey="$curr_net.200"
    new_honey="$curr_net.$(jot -r 1 2 254)"
    sed -i "s/$old_honey/$new_honey/g" "$dhcpd_conf"

    old_mac="00:22:3f:e3:1f:bf"
    new_mac="$1"

    time_stamp "Updating the MAC address of the honeypot..."
    sed -i "s/$old_mac/$new_mac/g" "$dhcpd_conf"

    time_stamp "Generating new DHCP network..."
    sed -i "s/$curr_net/$new_net/g" "$dhcpd_conf"
    time_stamp "DHCP will be using this network: $new_net.0/24"

    new_honey_ip="$(honey_ip)"
    time_stamp "The honeypot will be assigned this IPv4 address: $new_honey_ip"

    time_stamp "Updating configuration on interface eth1..."
    sed -i "s/$curr_net/$new_net/g" "$interfaces"

    time_stamp "Updating honssh.cfg.default..."
    sed -i "s/$old_honey/$new_honey/g" "$hs_default_cfg" 
    sed -i "s/$curr_net/$new_net/g" "$hs_default_cfg"
    time_stamp "Making active configuration file, honssh.cfg, from honssh.cfg.default..."
    cp "$hs_default_cfg" "$hs_active_cfg"

    time_stamp "Restarting the eth1 interface..."
    ifdown eth1 &>/dev/null
    ifup eth1 &>/dev/null
    time_stamp "IPv4 address has been assigned to the eth1 interface: $new_net.1"

    time_stamp "Restarting DHCP server..."
    service isc-dhcp-server restart &>/dev/null
}


# Chooses a new SSH port for Bifrozt administration at random.
function conf_new_ssh()
{
    time_stamp "Selecting a new SSH port for Bifrozt administration..."

    new_ssh_port="$(jot -r 1 49152 65535)"
    old_ssh_port="$(grep ^'Port' $sshd_conf | awk '{ print $2 }')"

    time_stamp "Updating sshd_config..."
    sed -i "s/$old_ssh_port/$new_ssh_port/g" "$sshd_conf"

    new_fw_ssh="-A INPUT -i eth0 -p tcp -m tcp --dport $new_ssh_port -j ACCEPT"
    curr_fw_ssh="-A INPUT -i eth0 -p tcp -m tcp --dport $old_ssh_port -j ACCEPT"

    time_stamp "Updating firewall rules..."
    sed -i "s/$curr_fw_ssh/$new_fw_ssh/g" "$ipv4_hater"

    time_stamp "Restarting SSH server..."
    service ssh restart &>/dev/null
    time_stamp "The SSH server is now running on TCP port: $new_ssh_port"
    time_stamp "Applying new firewall rules..."
    iptables-restore < "$ipv4_hater"
    time_stamp "The firewall is now accepting SSH connections on TCP port: $new_ssh_port"
}


# Validates MAC address. If the MAc validation fails it will terminate the script.
function check_mac()
{
    if [[ "$1" =~ ^([a-fA-F0-9]{2}:){5}[a-zA-Z0-9]{2}$ ]]
    then
        main "$1" | tee "$setup_log"
    else
        time_stamp "FAILURE: The MAC address you provided, \"$1\", does not appear to be valid."
        exit 1
    fi
}


# Returns the IPv4 address from the dhcpd.conf
function honey_ip()
{
    grep 'fixed-address' "$dhcpd_conf" \
    | awk '{ print $2 }' \
    | cut -d ';' -f1
}


# Preforms some very simple sanity checking before calling the required functions
function main()
{
    script_banner

    if [ "$(id -u)" = "0" ]
    then
        time_stamp "Are we root?...Yes"
    else
        time_stamp "FAIL: YOU.MUST.BE.ROOT. $Script stopping execution."
        exit 1
    fi

    if [ "$(check_distro)" = "Ubuntu" ]
    then
        time_stamp "Is this operating system Ubuntu?...Yes"
    else
        time_stamp "FAIL: Distro is not Ubuntu. $Script stopping execution."
        exit 1
    fi

    if [ "$(check_if)" -ge "2" ]
    then
        time_stamp "Do we have two network interface cards?...Yes"
    else
        time_stamp "FAIL: This machine has less than two network interface cards. $Script expected to find \"eth0\" and \"eth1\"."
        exit 1
    fi

    apt_get_things
    git_clone "$git_bzans" "$dst_bzans"
    gen_ssh_keys "$bz_key"
    run_play "$dst_bzans/playbook.yml" "$dst_bzans/hosts"
    setup_dhcp "$1"
    conf_new_ssh
    time_stamp "$Script has completed its execution. Do the following:"
    time_stamp "Note what port SSH is running on."
    time_stamp "If the honeypot is running, shut it off."
    time_stamp "Reboot Bifrozt (this machine)."
    time_stamp "Start the honeypot machine once Bifrozt is rebooted."
    time_stamp "Start HonSSH with: sudo honsshctrl start."
}


if [ "$#" != "1" ]
then
    time_stamp "ERROR: Missing argument. $Script requires the MAC address of your honeypot."
    exit 1
else
    check_mac "$1"
fi


exit 0
