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
declare -rx Script="${0##*/}"


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
    apt-get install software-properties-common -y
    apt-add-repository ppa:ansible/ansible -y
    apt-get update &>/dev/null
    apt-get install ansible git openssh-server -y &>/dev/null
}


# Cloning bifrozt-ansible into /root/bifrozt-ansible
function git_clone()
{
    git clone https://github.com/Bifrozt/bifrozt-ansible.git /root/bifrozt-ansible
}


# Generate SSH keys for root
function gen_ssh_keys()
{
    if [ ! -d "/root/.ssh" ]
    then
        mkdir "/root/.ssh"
        chmod 0700 "/root/.ssh"
        chown root:root "/root/.ssh"
    fi
    ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
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

    echo "$(date +"%Y-%m-%d %T") - INFO: Generating /root/.ssh/authorized_keys..."
    cat "/root/.ssh/id_rsa.pub" > ".ssh/authorized_keys"

    echo "$(date +"%Y-%m-%d %T") - INFO: Executing the playbook now..."
    IPV4="$(find_host_ipv4)"
    sed -i "s/IPv4_OR_FQDN/$IPV4/g" /root/bifrozt-ansible/hosts
    # If the playbook returns a non-zero exit code, exit 1, if returning zero, sleep 10 seconds and rebboot
    ansible-playbook /root/bifrozt-ansible/playbook.yml -i /root/bifrozt-ansible/hosts \
    && reboot_system \
    || exit 1
}


# Starts execution of script
main


exit 0


