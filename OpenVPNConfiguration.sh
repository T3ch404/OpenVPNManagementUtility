#!/bin/bash

# Name:     OpenVPNConfiguration.sh
# Author:   Noah DaMetz
# Created:  04/01/2021
# Modified: 06/26/2021

# The purpose of this script is to simplify the process of creating
# and revoking certificates to be used with an OpenVPN server. This script
# assumes you have setup your OpenVPN server following the Digital Ocean OpenVPN guide.

#=============== VARIABLES ===============
EASYRSADIR=../easy-rsa
CLIENTCONFIGDIR=../client-configs
serverIP=127.0.0.1

CAUser=user

# Text Colors
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'

prompt=">> "

#=============== FUNCTIONS ===============
# This function should be called after the CA server has signed and returned the client certificate
# $username MUST be defined before calling this function
function createOVPN {

	if [ ! -f "/tmp/$username.crt" ]; then
		echo -e "${RED}FILE MISSING ERROR - /tmp/$username.crt does not exist!${NC}"
		exit 3
	fi
        cp /tmp/$username.crt $CLIENTCONFIGDIR/keys

        # The following was stolen from the DigitalOcean tutorial
        KEY_DIR=$CLIENTCONFIGDIR/keys
        OUTPUT_DIR=$CLIENTCONFIGDIR/files
        BASE_CONFIG=$CLIENTCONFIGDIR/base.conf

        cat ${BASE_CONFIG} \
        	<(echo -e '<ca>') \
                ${KEY_DIR}/ca.crt \
                <(echo -e '</ca>\n<cert>') \
                ${KEY_DIR}/${username}.crt \
                <(echo -e '</cert>\n<key>') \
                ${KEY_DIR}/${username}.key \
                <(echo -e '</key>\n<tls-crypt>') \
                ${KEY_DIR}/ta.key \
                <(echo -e '</tls-crypt>') \
                > ${OUTPUT_DIR}/${username}.ovpn

         echo -e "${GREEN}The new user .ovpn file has successfully been created!"
         echo -e "It has been saved to $OUTPUT_DIR${NC}"
}

function secureCopyToCA() {
	# Copy certificate request to CA server and check to make sure the transfer was successful
	scp $EASYRSADIR/pki/reqs/$username.req $CAUser@$serverIP:/tmp
	if [ $? -ne 0 ]; then
		echo -e "${RED}SECURE COPY ERROR - Secure copy failed to send $EASYRSADIR/pki/reqs/$Username.req to CA Server.${NC}"
		exit 1
	fi
}

function checkFile {
	if [ -f $1 ]; then
		return 0
	else
		return 1
	fi
}

#=============== MAIN BEGIN ===============

if [ "$EUID" -ne 0 ]; then
	echo "Please run this script with 'sudo'"
	exit 1
fi

echo "Welcome to the"
echo "   ____  _    __ ____   _   __   ______ ____   _   __ ______ ____ ______ __  __ ____   ___   ______ ____ ____   _   __
  / __ \| |  / // __ \ / | / /  / ____// __ \ / | / // ____//  _// ____// / / // __ \ /   | /_  __//  _// __ \ / | / /
 / / / /| | / // /_/ //  |/ /  / /    / / / //  |/ // /_    / / / / __ / / / // /_/ // /| |  / /   / / / / / //  |/ / 
/ /_/ / | |/ // ____// /|  /  / /___ / /_/ // /|  // __/  _/ / / /_/ // /_/ // _, _// ___ | / /  _/ / / /_/ // /|  /  
\____/  |___//_/    /_/ |_/   \____/ \____//_/ |_//_/    /___/ \____/ \____//_/ |_|/_/  |_|/_/  /___/ \____//_/ |_/   
                                                                                                                      "
echo "   __  __ ______ ____ __     ____ ________  __
  / / / //_  __//  _// /    /  _//_  __/\ \/ /
 / / / /  / /   / / / /     / /   / /    \  / 
/ /_/ /  / /  _/ / / /___ _/ /   / /     / /  
\____/  /_/  /___//_____//___/  /_/     /_/   
                                              "

while true; do
	echo "Enter the IP address of the Certificate Autority server that will be used"
	read -p $prompt serverIP

	echo "Confirm (Y or N) that the entered IP ($serverIP) is correct"
	read -p $prompt userInput
	shopt -s nocasematch
	if [[ $userInput == "y" ]]; then
		break
	elif [[ $userInput == "n" ]]; then
		echo -e "${YELLOW}Please try again${NC}"
	else
		echo -e "${RED}unrecognized input${NC}"
	fi
done

while true; do
	echo -e "\n\n${BLUE}===================== Main Menu =====================${NC}"
	echo "(1) Create new client configuration file"
	echo "(2) Revoke a client configuration file"
	echo "(3) Advanced options"
	echo "(4) Quit"

	read -p $prompt MenuInput

	case $MenuInput in

		1)
			# Get username from user
			echo "Please enter the username for the new client (e.g. 'client1')"
			read -p $prompt username

			# Check if file with this username already exists
			if checkFile "$EASYRSADIR/pki/private/$username.key"; then
				echo -e "${RED}FILE ALREADY EXISTS ERROR - $EASYRSADIR/pki/private/$username.key already exists${NC}"
				exit 2
			fi

			# Create new client key and certificate request
			$EASYRSADIR/easyrsa gen-req $username nopass
			cp $EASYRSADIR/pki/private/$username.key $CLIENTCONFIGDIR/keys

			read -p "Enter the username for the VPN server:" CAUser

			# Copy client certificate to CA server
			secureCopyToCA

			# Wait for user to complete the nessisary steps on the CA server
			echo -e "${YELLOW}Please open a new terminal and remote into the CA server. Once logged in,"
				echo "run the ./CAconfig script and follow the instructions to sign a new client certificate.${NC}"
				sleep 20s
				read -p "When prompted to log out and return to the VPN server, press the 'Enter' key in this window to continue."

			# Create .ovpn file from the returned client certificate
			createOVPN
			;;

		2)
			# Waite for the user to complete the nessisary steps on the CA server
			echo -e "${YELLOW}Please make sure to run the ./CAconfig script on the Certificate Authority server using the revoke client certificate option first.${NC}"
			read -p "Press enter to continue."

			# Copy new crl.pem file to openvpn config directory, then restart the service.
			cp /tmp/crl.pem /etc/openvpn/server/
			systemctl restart openvpn-server@server.service
			;;

		3)
			while true; do
				# This menu is used in the event that the script fails to transfer certificate requests or create the .ovpn file.
				echo -e "\n\n${BLUE}=============== Advanced Options Menu ===============${NC}"
				echo "(1) Secure copy failed"
				echo "(2) Creating .ovpn file failed"
				echo "(3) Return to Main Menu"

				# Wait for user to select a menu option.
				read -p $prompt AdvancedMenuInput
			
				case $AdvancedMenuInput in

					1)
						# Wait for user to enter the username for the new user configuration.
						echo "Enter the username that was used to create the client certificate"
						read -p $prompt username

						# Check to make sure the certificate request associated with the username in question is available.
						if [ ! checkFile "$EASYRSADIR/pki/reqs/$username.req" ]; then
							echo -e "${RED}FILE MISSING ERROR - $EASYRSADIR/pki/reqs/$username.req does not exist!${NC}"
							exit 3
						fi

						read -p "Enter the username for the VPN server:" CAUser

						# Copy client certificate to CA server.
						secureCopyToCA

						# Wait for user to complete the nessisary steps on the CA server.
						echo -e "${YELLOW}Open a new terminal and remote into the CA server. Once logged in,"
						echo -e "run the ./CAconfig script and follow the instructions to sign a new client certificate.${NC}"
						sleep 20s
						read -p "When prompted to log out and return to the VPN server, press the 'Enter' key in this window to continue."

						# Create .ovpn file from the returned client certificate.
						createOVPN

						break
						;;
					2)
						# Wait for user to enter the username for the new user configuration.
						echo "Please enter the username that was used to create the client certificate"
						read -p $prompt username

						# Check to make sure the signed certificate is in the appropriate keys directory
						if [ ! checkFile "$CLIENTCONFIGDIR/keys/$username.crt" ]; then
							echo -e "${RED}FILE MISSING ERROR - $CLIENTCONFIGDIR/keys/$username.key does not exist!${NC}"
							exit 3
						fi

						# Create .ovpn file from the returned client certificate.
						createOVPN

						break
						;;
					3)
						break
						;;
					*)
						# User entered something unexpected.
						echo -e "${RED}Unrecognized input!${NC}"
						continue
						;;
				esac
			done
			;;
		4)
			# User wants to quit from the Main Menu
			echo "Good-bye!"
			exit 0
			;;
		*)
			# User entered something unexpected.
			echo -e "${RED}Unrecognized input!${NC}"
			continue
			;;
	esac

	echo "Would you like to quit? (Y or N)"
	read -p $prompt userInput
	if [[ $userInput == "y" ]]; then
		break
	fi

done

echo "Good-bye!"
exit 0