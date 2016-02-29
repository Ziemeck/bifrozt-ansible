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
#   --------------------------------------------------------------
#
declare -rx Script="${0##*/}"
declare created="2016, Feb 24"
declare author="Are Hansen"
declare version="0.0.3-DEV"


# Outputs information about this script and exits.
function script_info()
{
echo "
    ========= $Script - $version - $created - $author =========

    This script a part of the Bifrozt honeypot router project. It's been 
    developed to assist end users to install the required software and
    configuration files in a quick and easy manner.

"
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


# Install any avalibel updates.
function apt_get_things()
{
    apt-get update &>/dev/null
    apt-get upgrade -y &>/dev/null
}


# Install Ansible dependencies.
function install_ansible()
{
    apt-get install software-properties-common -y &>/dev/null
    apt-add-repository ppa:ansible/ansible -y &>/dev/null
    apt-get update &>/dev/null
    apt-get install ansible git openssh-server -y &>/dev/null
    sed -i 's/#host_key_checking/host_key_checking/g' /etc/ansible/ansible.cfg
}


# Cloning bifrozt-ansible into /tmp/bifrozt-ansible
function git_clone()
{
    git clone https://github.com/Bifrozt/bifrozt-ansible.git /tmp/bifrozt-ansible &>/dev/null
}


# Generate SSH keys for root
function gen_ssh_keys()
{
    if [ ! -d "/etc/ansible/BZKEY" ]
    then
        mkdir "/etc/ansible/BZKEY"
        chmod 0700 "/etc/ansible/BZKEY"
        chown root:root "/etc/ansible/BZKEY"
    fi

    ssh-keygen -f /etc/ansible/BZKEY/id_rsa -t rsa -N '' &>/dev/null

    if [ ! -e "/etc/ansible/BZKEY/id_rsa.pub" ]
    then
        echo "$(date +"%Y-%m-%d %T") - FAIL: id_rsa.pub not found in expected location."
    	exit 1
    else
        echo "$(date +"%Y-%m-%d %T") - INFO: Generating /root/.ssh/authorized_keys..."
        cat "/etc/ansible/BZKEY/id_rsa.pub" > "/root/.ssh/authorized_keys"
    	chmod 0600 "/etc/ansible/BZKEY/id_rsa.pub"
        sed -i 's/#private_key_file = \/path\/to\/file/private_key_file = \/etc\/ansible\/BZKEY\/id_rsa/g' /etc/ansible/ansible.cfg 
    fi
}


# Gets the IPv4 address of eth0
function find_host_ipv4()
{
    ifconfig eth0 \
    | grep 'inet addr:' \
    | cut -d ':' -f2 \
    | awk '{ print $1 }'
}


# Reboot system after 10 seconds
function reboot_system()
{
    echo "$(date +"%Y-%m-%d %T") - OK: Looks like everything worked out fine, rebooting system in 10 seconds...."
    echo "$(date +"%Y-%m-%d %T") - INFO: Press CTRL + C to abort reboot."
    sleep 10
    reboot
}

# Preforms some very simple sanity checking before calling the required functions
function main()
{
    if [ "$#" != "0" ]
    then
        echo "$(date +"%Y-%m-%d %T") - FAIL: $Script does NOT accept any arguments."
        exit 1
    fi

    if [ "$(id -u)" = "0" ]
    then
        echo "$(date +"%Y-%m-%d %T") - OK: Looks like we are root..."
    else
        echo "$(date +"%Y-%m-%d %T") - FAIL: MUST.BE.ROOT. $Script stopping execution."
        exit 1
    fi

    if [ "$(check_distro)" = "Ubuntu" ]
    then
        echo "$(date +"%Y-%m-%d %T") - OK: Distro is Ubuntu..."
    else
        echo "[!] - FAIL: Distro is not Ubuntu. $Script stopping execution."
        exit 1
    fi

    if [ "$(check_if)" -ge "2" ]
    then
        echo "$(date +"%Y-%m-%d %T") - OK: Found two network interface cards..."
    else
        echo "$(date +"%Y-%m-%d %T") - FAIL: This machine has less than two network interface cards. $Script stopping execution."
        exit 1
    fi

    echo "$(date +"%Y-%m-%d %T") - INFO: Updating the system..."
    apt_get_things

    echo "$(date +"%Y-%m-%d %T") - INFO: Installing Ansible..."
    install_ansible

    echo "$(date +"%Y-%m-%d %T") - INFO: Cloning Bifrozt from GitHub..."
    git_clone

    echo "$(date +"%Y-%m-%d %T") - INFO: Generating SSH keys..."
    gen_ssh_keys

    echo "$(date +"%Y-%m-%d %T") - INFO: Executing the playbook now..."
    IPV4="$(find_host_ipv4)"
    sed -i "s/IPv4_OR_FQDN/$IPV4/g" /tmp/bifrozt-ansible/hosts
    # If the playbook returns a non-zero exit code, exit 1, if returning zero, sleep 10 seconds and rebboot
    ansible-playbook /tmp/bifrozt-ansible/playbook.yml -i /tmp/bifrozt-ansible/hosts \
    && reboot_system \
    || exit 1
}


case "$1" in
    info)
        script_info
        ;;
    *)
        main
        ;;
esac


exit 0


