#!/bin/bash

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
RESET='\033[0m'
HIDDENDIR='ssh' # Replace with "HIDDENDIR=$(< /dev/urandom tr -dc a-z0-9 | head -c5)" If you want to create a new hidden directory (meaning a new server) everytime you run this script.
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
main() {
    ascii
    # Don't forget to install the dependencies
    check_dependencies
    # Set permissions
    mkdir -p /var/lib/tor/${HIDDENDIR}/
    chown -R tor:tor /var/lib/tor/${HIDDENDIR}/
    chmod 0700 /var/lib/tor/${HIDDENDIR}/

    # Configure the hidden service
    
    echo -e "\n#SSH connections.\nHiddenServiceDir /var/lib/tor/${HIDDENDIR}/\nHiddenServicePort 22 127.0.0.1:51984" >> /etc/tor/torrc

    # Replace all occurrences of 22 with 51984: 
    sed -i 's/Port 22/Port 51984/g' /etc/ssh/sshd_config
    restart_services

    # Setting up an authentication method
    echo -e "${CYAN}Select an authentication method:${RESET}
                 [${YELLOW}0${RESET}] ${MAGENTA}Password${RESET}
                 [${YELLOW}1${RESET}] ${MAGENTA}Keys [Recommended]${RESET}"

    read -p "Enter your choice: " method

    case $method in
        0)
            passwd
            ;;
        1)
            setup_authkeys
            ;;
        *)
            echo "Invalid selection. Please enter 0 or 1."
            ;;
    esac


    echo "${GREEN}Everything's done! Here is your server's onion link: $(cat /var/lib/tor/${HIDDENDIR}/hostname)${RESET}"
}

main
