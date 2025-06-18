#!/bin/bash
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
RESET='\033[0m'


TORDIR="tor"
TORCONFIG="torrc" # Name of your tor config file.
HIDDENDIR="ssh" # Replace with "HIDDENDIR=$(< /dev/urandom tr -dc a-z0-9 | head -c5)" If you want to create a new hidden directory (meaning a new server) everytime you run this script.
# Thank you figlet.
ascii() {
    colors=("$RED" "$GREEN" "$YELLOW" "$BLUE" "$MAGENTA" "$CYAN")
    random_color=${colors[RANDOM % ${#colors[@]}]}
    ascii_art=$(cat <<EOF
${random_color}
              ____ ____  _   _
          ___/ ___/ ___|| | | |
         / _ \___ \___ \| |_| |
        | (_) |__) |__) |  _  |
         \___/____/____/|_| |_| - SSH OVER TOR
${RESET}
EOF
)
    echo -e "$ascii_art"
}

check_dependencies() {
    if command -v ssh &> /dev/null && command -v tor &> /dev/null; then
        echo -e "${GREEN}Dependencies installed.${RESET}"
    else
        echo -e "${RED}Dependencies not installed. Exiting.${RESET}"
        exit 1
    fi
}

restart_services() {
    if systemctl --version &> /dev/null; then
        systemctl restart sshd
        systemctl restart tor
    elif initctl version &> /dev/null; then
        initctl restart sshd
        initctl restart tor
    elif service --status-all &> /dev/null; then
        service sshd restart
        service tor restart
    elif sv --version &> /dev/null; then
        sv restart sshd
        sv restart tor
    else
        echo -e "${RED}No recognized init system found or an error occurred. Restart tor and ssh manually.${RESET}"
    fi
}

# Refer: https://community.torproject.org/onion-services/advanced/client-auth/
# NOTE: This only sets up the server and not the client, you have to do it yourself.
setup_authkeys() {
    mkdir -p $HOME/.ssh/
    touch $HOME/.ssh/authorized_keys
    echo -e "${GREEN}Server setup was successful, please import your SSH Keys to the host pc. If you want to add key authentication to your tor server as well visit https://community.torproject.org/onion-services/advanced/client-auth/. Then you can run the commented commands from line 62-69 to setup the server.${RESET}"
    # # Generate a key using the x25519 algorithm
    # openssl genpkey -algorithm x25519 -out /tmp/k1.prv.pem
    # # Private Key
    # cat /tmp/k1.prv.pem | grep -v " PRIVATE KEY" | base64 -d | tail --bytes=32 | base32 | sed 's/=//g' > /tmp/k1.prv.key
    # # Public Key
    # openssl pkey -in /tmp/k1.prv.pem -pubout | grep -v " PUBLIC KEY" | base64 -d | tail --bytes=32 | base32 | sed 's/=//g' > /tmp/k1.pub.key
    # pub_key=$(cat /tmp/k1.pub.key)
    # echo "descriptor:x25519:$pub_key" >> /var/lib/tor/ssh/authorized_clients/device.auth 
    ## NOTE: This works fine and sets up the server, but the client needs to be configured by the user themselves so read the guide!
}
# Function to remove the hidden service.
del() {
    rm -rf /var/lib/${TORDIR}/${HIDDENDIR}/
    sed -i "/#SSH connections./d; /HiddenServiceDir \/var\/lib\/${TORDIR}\/${HIDDENDIR}\//d; /HiddenServicePort 22 127.0.0.1:51984/d" /etc/tor/${TORCONFIG}
    restart_services
    echo -e "${GREEN}Successfull.${RESET}"

}
# Function to create the SSH server
ssh() {
    check_dependencies
    # Check If the hidden directory already exists.
    if [ -d "/var/lib/${TORDIR}/${HIDDENDIR}" ]; then 
        echo -e "${RED}The hidden directory ${HIDDENDIR} already exists.${RESET}" 
        exit 1
    fi 

    # Set permissions
    mkdir -p /var/lib/${TORDIR}/${HIDDENDIR}/
    chown -R tor:tor /var/lib/${TORDIR}/${HIDDENDIR}/
    chmod 0700 /var/lib/${TORDIR}/${HIDDENDIR}/

    # Configure the hidden service
    
    echo -e "\n#SSH connections.\nHiddenServiceDir /var/lib/${TORDIR}/${HIDDENDIR}/\nHiddenServicePort 22 127.0.0.1:51984" >> /etc/tor/${TORCONFIG}

    # Replace all occurrences of 22 with 51984.
    sed -i "s/Port 22/Port 51984/g" /etc/ssh/sshd_config
    restart_services

    # Setting up an authentication method
    echo -e "${CYAN}Select an authentication method:${RESET}
                 [${YELLOW}0${RESET}] ${MAGENTA}Password${RESET}
                 [${YELLOW}1${RESET}] ${MAGENTA}Keys [Recommended]${RESET}"

    while true; do
        read -p "Enter your choice: " method
        case $method in
            0) passwd; break;;
            1) setup_authkeys; break;;
            *) echo "Invalid selection. Please enter 0 or 1.";;
        esac
    done

    HOSTNAME=$(cat /var/lib/${TORDIR}/${HIDDENDIR}/hostname)
    echo -e "${GREEN}Everything's done! Here is your server's onion link: $(cat /var/lib/${TORDIR}/${HIDDENDIR}/hostname)${RESET}\n"
    echo -e "${GREEN}You can SSH into it using the command${RESET} ${CYAN}torsocks -p {PORT} ssh ${HOSTNAME}${RESET}${GREEN} or add this to your ${HOME}/.ssh/config${RESET}${CYAN}\nHost hidden\nHostname ${HOSTNAME}\nProxyCommand /usr/bin/nc -x localhost:9050 %h %p${RESET}\n${GREEN}You can then ssh into it using the command 'ssh hidden'.\n${RESET}"
}
main() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Please run as root.${RESET}"
        exit 1
    fi
    ascii
    TEMP=$(getopt -o d:c:h: --long create,del,directory:,config:,hiddendir: -- "$@")
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to parse options.${RESET}"
        exit 1
    fi
    eval set -- "$TEMP"
    ACTION=""
    while true; do
        case "$1" in
            --create) ACTION="create"; shift ;;
            --del) ACTION="del"; shift ;;
            -d|--directory) TORDIR="$2"; shift 2 ;;
            -c|--config) TORCONFIG="$2"; shift 2 ;;
            -h|--hiddendir) HIDDENDIR="$2"; shift 2 ;;
            --) shift; break ;;
            *) echo -e "${RED}Invalid option: $1${RESET}"; exit 1 ;;
        esac
    done
    if [[ -z "$ACTION" ]]; then
        echo -e "${RED}Usage: $0 --create | --del [-d dir] [-c conf] [-h hiddendir]${RESET}"
        exit 1
    fi
    if [[ "$ACTION" == "create" ]]; then
        ssh
    elif [[ "$ACTION" == "del" ]]; then
        del
    else
        echo -e "${RED}Invalid action specified.${RESET}"
        exit 1
    fi
}



main "$@"
