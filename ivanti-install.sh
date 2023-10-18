#!/usr/bin/env bash
#
# +-------------------------------------------------------------------------+
# | prepare.sh                                                              |
# +-------------------------------------------------------------------------+
# | Copyright © 2023 TTI, Inc.                                              |
# |                  euis.network(at)de.ttiinc.com                          |
# +-------------------------------------------------------------------------+

# +----- Variables ---------------------------------------------------------+
datetime="$(date "+%Y-%m-%d-%H-%M-%S")"
logfile="/tmp/prepare_RHEL_${datetime}.log"
width=80

RED=$(tput setaf 1)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
YN="(Yes|${BRIGHT}No${NORMAL}) >> "

# +----- Functions ---------------------------------------------------------+

echo_equals() {
    counter=0
    while [ $counter -lt "$1" ]; do
    printf '='
    (( counter=counter+1 ))
    done
}

echo_title() {
    title=$1
    ncols=$(tput cols)
    nequals=$(((width-${#title})/2-1))
    tput setaf 4
    echo_equals "$nequals"
    tput setaf 6
    printf " %s " "$title"
    tput setaf 4
    echo_equals "$nequals"
    tput sgr0
    echo
}

echo_Right() {
    text=${1}
    echo
    tput cuu1
    tput cuf "$((${width} -1))"
    tput cub ${#text}
    echo "${text}"
}

echo_OK() {
    tput setaf 2
    echo_Right "[ OK ]"
    tput sgr0
}

echo_Done() {
    tput setaf 2
    echo_Right "[ Done ]"
    tput sgr0
}

echo_NotNeeded() {
    tput setaf 3
    echo_Right "[ Not Needed ]"
    tput sgr0
}

echo_Skipped() {
    tput setaf 3
    echo_Right "[ Skipped ]"
    tput sgr0
}

echo_Failed() {
    tput setaf 1
    echo_Right "[ Failed ]"
    tput sgr0
}

get_User() {
    if ! [[ $(id -u) = 0 ]]; then
        echo -e "\n ${RED}[ Error ]${NORMAL} This script must be run as root.\n"
        exit 1
    fi
}

antwoord() {
    read -p "${1}" antwoord
        if [[ ${antwoord} == [yY] || ${antwoord} == [yY][Ee][Ss] ]]; then
            echo "yes"
        else
            echo "no"
        fi
}

get_IdentityCoreCertificate() {
    echo -n "Enter your Identity Core Certificate: "
    read -p "${1}" certificate
    echo "${certificate}"
}

get_IvantiServer() {
    echo -n "Enter your Ivanti Coreserver FQDN: "
    read -p "${1}" coreserver
    echo "${coreserver}"
}

firewalld_querry() {
    firewalld="$(antwoord "Do you want to open Ports 22TCP, 9593TCP, 9594TCP, 9595TCP/UDP in firewall? ${YN}")"
}
firewalld_ports() {
    echo -n -e "Opening Ports in Firewalld\r"
    if [[ "${firewalld}" = "yes" ]]; then
        firewalld-cmd --permanent --add-port=22/tcp
        firewalld-cmd --permanent --add-port=9593/tcp
        firewalld-cmd --permanent --add-port=9594/tcp
        firewalld-cmd --permanent --add-port=9595/tcp
        firewalld-cmd --permanent --add-port=9595/udp
        firewalld-cmd --reload
        echo_Done
    else
        echo_Skipped
    fi
}

sudoers_querry() {
    sudoers="$(antwoord "Do you want to add landesk user to sudoers? ${YN}")"
}
sudoers_add() {
    echo -n -e "Adding landesk user to sudoers\r"
    if [[ "${sudoers}" = "yes" ]]; then
        echo "## Allowing landesk user to run all commands" >> /etc/sudoers
        echo "landesk ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        echo "Defaults:landesk !requiretty" >> /etc/sudoers
        echo_Done
    else
        echo_Skipped
    fi
}

nixconfig_download() {
    echo -n -e "Downloading nixconfig.sh\r"
    mkdir -p /tmp/ems
    wget -P /tmp/ems http://${coreserver}/ldlogon/unix/nixconfig.sh
    echo_Done
}

agent_install() {
    echo -n -e "Installing Ivanti Agent\r"
    chmod +x /tmp/ems/nixconfig.sh
    /tmp/ems/nixconfig.sh -p -a ${coreserver} -i all -k ${certificate}.0
    echo_Done
}

# +----- Main --------------------------------------------------------------+
get_User

echo_title "Choose Options"

get_IdentityCoreCertificate
get_IvantiServer
firewalld_querry
sudoers_querry

echo_title "Installing"

firewalld_ports
sudoers_add
nixconfig_download
agent_install

echo_title "I'm done."
exit 0
